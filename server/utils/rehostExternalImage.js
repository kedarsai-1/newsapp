const { cloudinary } = require('../config/cloudinary');
const { getPublisherReferer } = require('./publisherReferer');

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

/**
 * Download a hotlinked image and upload to Cloudinary.
 * @returns {{ ok: boolean, url?: string, publicId?: string, reason?: string, already?: boolean }}
 */
async function rehostExternalImageToCloudinary(
  imageUrl,
  { referer, skipIngestEnvCheck = false } = {},
) {
  if (!skipIngestEnvCheck && process.env.INGEST_REHOST_IMAGES === 'false') {
    return { ok: false, reason: 'disabled' };
  }
  if (!imageUrl || typeof imageUrl !== 'string') return { ok: false, reason: 'missing' };
  if (isCloudinaryUrl(imageUrl)) return { ok: true, url: imageUrl, already: true };

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

    const ext =
      ct === 'image/png' ? 'png'
      : ct === 'image/webp' ? 'webp'
      : ct === 'image/gif' ? 'gif'
      : ct === 'image/avif' ? 'avif'
      : 'jpg';

    const dataUri = `data:${ct || 'image/jpeg'};base64,${buf.toString('base64')}`;
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
    return { ok: true, url: secure, publicId: upload.public_id };
  } catch (e) {
    clearTimeout(to);
    const msg =
      e?.message === 'cloudinary_upload_timeout'
        ? 'upload_timeout'
        : e?.name === 'AbortError'
          ? 'timeout'
          : e?.message || 'error';
    return { ok: false, reason: msg };
  }
}

module.exports = {
  rehostExternalImageToCloudinary,
  isCloudinaryUrl,
  isBlockedFetchHost,
};
