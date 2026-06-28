const fs = require('fs');
const path = require('path');
const { createHash } = require('crypto');
const { cloudinary } = require('../config/cloudinary');
const { getPublisherReferer } = require('./publisherReferer');
const { isCloudinaryAvailable } = require('./cloudinaryHealth');

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

function isLocalMediaUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('/media/ingest/');
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

function extensionForContentType(ct) {
  const type = String(ct || '').toLowerCase();
  if (type === 'image/png') return 'png';
  if (type === 'image/webp') return 'webp';
  if (type === 'image/gif') return 'gif';
  if (type === 'image/avif') return 'avif';
  return 'jpg';
}

function localMediaDir() {
  return process.env.INGEST_LOCAL_MEDIA_DIR
    || path.join(__dirname, '..', '..', 'newsapp-media', 'ingest');
}

function publicMediaBaseUrl() {
  const configured = process.env.MEDIA_PUBLIC_BASE_URL?.trim();
  if (configured) return configured.replace(/\/$/, '');
  const port = process.env.PORT || 5001;
  const host = process.env.MEDIA_PUBLIC_HOST?.trim() || '127.0.0.1';
  return `http://${host}:${port}`;
}

async function fetchRemoteImage(imageUrl, { referer } = {}) {
  let parsed;
  try {
    parsed = new URL(imageUrl.trim());
  } catch {
    return { ok: false, reason: 'invalid_url' };
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return { ok: false, reason: 'scheme' };
  if (isBlockedFetchHost(parsed.hostname)) return { ok: false, reason: 'blocked_host' };

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 15000);
  try {
    const ref =
      (referer && String(referer).trim())
      || getPublisherReferer(parsed.href)
      || getPublisherReferer(parsed.hostname)
      || null;

    const headers = {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (ref) {
      headers.Referer = ref;
      headers.Origin = ref;
    }

    let res = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers,
    });
    if (!res.ok && (res.status === 401 || res.status === 403)) {
      const { Referer, Origin, ...noRef } = headers;
      res = await fetch(parsed.href, {
        redirect: 'follow',
        signal: ac.signal,
        headers: noRef,
      });
    }
    clearTimeout(to);
    if (!res.ok) return { ok: false, reason: `http_${res.status}` };

    const ct = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (ct && !ct.startsWith('image/')) return { ok: false, reason: `not_image_${ct}` };

    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length) return { ok: false, reason: 'empty' };
    if (buf.length > 5 * 1024 * 1024) return { ok: false, reason: 'too_large' };

    return { ok: true, buf, contentType: ct || 'image/jpeg', sourceUrl: parsed.href };
  } catch (e) {
    clearTimeout(to);
    const msg = e?.name === 'AbortError' ? 'timeout' : e?.message || 'error';
    return { ok: false, reason: msg };
  }
}

async function uploadBufferToCloudinary(buf, contentType) {
  const ext = extensionForContentType(contentType);
  const dataUri = `data:${contentType || 'image/jpeg'};base64,${buf.toString('base64')}`;
  const uploadTimeoutMs = Math.min(
    120000,
    Math.max(8000, Number(process.env.CLOUDINARY_UPLOAD_TIMEOUT_MS || 45000)),
  );
  const upload = await Promise.race([
    cloudinary.uploader.upload(dataUri, {
      folder: 'newsapp/external',
      resource_type: 'image',
      overwrite: false,
      unique_filename: true,
      format: ext,
    }),
    new Promise((_, rej) => {
      setTimeout(() => rej(new Error('cloudinary_upload_timeout')), uploadTimeoutMs);
    }),
  ]);
  const secure = upload?.secure_url || upload?.url;
  if (!secure) return { ok: false, reason: 'upload_failed' };
  return { ok: true, url: secure, publicId: upload.public_id, backend: 'cloudinary' };
}

async function saveBufferToLocalMedia(buf, contentType, sourceUrl) {
  const ext = extensionForContentType(contentType);
  const hash = createHash('sha256').update(String(sourceUrl)).digest('hex').slice(0, 32);
  const name = `${hash}.${ext}`;
  const dir = localMediaDir();
  await fs.promises.mkdir(dir, { recursive: true });
  const filePath = path.join(dir, name);
  try {
    await fs.promises.access(filePath, fs.constants.R_OK);
  } catch {
    await fs.promises.writeFile(filePath, buf);
  }
  const url = `${publicMediaBaseUrl()}/media/ingest/${name}`;
  return { ok: true, url, backend: 'local', path: filePath };
}

/**
 * Download a hotlinked image and upload to Cloudinary (legacy direct API).
 */
async function rehostExternalImageToCloudinary(
  imageUrl,
  { referer, skipIngestEnvCheck = false } = {},
) {
  if (!skipIngestEnvCheck && process.env.INGEST_REHOST_IMAGES === 'false') {
    return { ok: false, reason: 'disabled' };
  }
  if (!imageUrl || typeof imageUrl !== 'string') return { ok: false, reason: 'missing' };
  if (isCloudinaryUrl(imageUrl)) return { ok: true, url: imageUrl, already: true, backend: 'cloudinary' };
  if (isLocalMediaUrl(imageUrl)) return { ok: true, url: imageUrl, already: true, backend: 'local' };

  if (!(await isCloudinaryAvailable())) {
    return { ok: false, reason: 'cloudinary_unavailable' };
  }

  const fetched = await fetchRemoteImage(imageUrl, { referer });
  if (!fetched.ok) return fetched;

  try {
    return await uploadBufferToCloudinary(fetched.buf, fetched.contentType);
  } catch (e) {
    const msg =
      e?.message === 'cloudinary_upload_timeout'
        ? 'upload_timeout'
        : e?.message || 'error';
    return { ok: false, reason: msg };
  }
}

/**
 * Ingest rehost: Cloudinary when available, else VPS disk + nginx `/media/ingest/`.
 */
async function rehostExternalImageForIngest(imageUrl, { referer } = {}) {
  if (process.env.INGEST_REHOST_IMAGES === 'false') {
    return { ok: false, reason: 'disabled' };
  }
  if (!imageUrl || typeof imageUrl !== 'string') return { ok: false, reason: 'missing' };
  if (isCloudinaryUrl(imageUrl)) return { ok: true, url: imageUrl, already: true, backend: 'cloudinary' };
  if (isLocalMediaUrl(imageUrl)) return { ok: true, url: imageUrl, already: true, backend: 'local' };

  const fetched = await fetchRemoteImage(imageUrl, { referer });
  if (!fetched.ok) return fetched;

  if (await isCloudinaryAvailable()) {
    try {
      const uploaded = await uploadBufferToCloudinary(fetched.buf, fetched.contentType);
      if (uploaded.ok) return uploaded;
    } catch (e) {
      console.warn('[rehost] Cloudinary upload failed, falling back to local media:', e?.message || e);
    }
  }

  try {
    return await saveBufferToLocalMedia(fetched.buf, fetched.contentType, fetched.sourceUrl);
  } catch (e) {
    return { ok: false, reason: e?.message || 'local_save_failed' };
  }
}

module.exports = {
  rehostExternalImageToCloudinary,
  rehostExternalImageForIngest,
  fetchRemoteImage,
  isCloudinaryUrl,
  isLocalMediaUrl,
  isBlockedFetchHost,
  localMediaDir,
  publicMediaBaseUrl,
};
