const crypto = require('crypto');
const { prisma } = require('../config/prisma');
const { publisherNameFromPost } = require('./serializers');

const SHARE_CODE_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const SHARE_CODE_LEN = 6;

function getShareWebBaseUrl(req) {
  const configured = process.env.SHARE_WEB_BASE_URL?.trim();
  if (configured) return configured.replace(/\/$/, '');
  if (req) {
    const proto = String(req.get('x-forwarded-proto') || req.protocol || 'http').split(',')[0].trim();
    const host = String(req.get('x-forwarded-host') || req.get('host') || '').split(',')[0].trim();
    if (host) return `${proto}://${host}`;
  }
  const port = Number(process.env.PORT) || 5001;
  const host = process.env.SHARE_WEB_HOST?.trim() || '127.0.0.1';
  return `http://${host}:${port}`;
}

function getAppBrandName() {
  return process.env.APP_NAME?.trim() || 'NewsNow';
}

function generateShareCode(length = SHARE_CODE_LEN) {
  const bytes = crypto.randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += SHARE_CODE_CHARS[bytes[i] % SHARE_CODE_CHARS.length];
  }
  return out;
}

async function ensureShareCodeForPost(postId, existingCode = null) {
  if (existingCode) return existingCode;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = generateShareCode();
    try {
      const updated = await prisma.newsPost.update({
        where: { id: postId },
        data: { shareCode: code },
        select: { shareCode: true },
      });
      return updated.shareCode;
    } catch (err) {
      if (err?.code === 'P2002') continue;
      throw err;
    }
  }
  throw new Error('Failed to allocate share code');
}

function buildShareUrl(shareCode, req) {
  const base = getShareWebBaseUrl(req);
  return `${base}/n/${shareCode}`;
}

function buildArticleUrl(postId, req) {
  const base = getShareWebBaseUrl(req);
  return `${base}/article/${postId}`;
}

function buildShareText({ title, shareUrl, sourceName, appName = getAppBrandName() }) {
  const headline = String(title || '').trim();
  const source = String(sourceName || 'News').trim() || 'News';
  const brand = String(appName || getAppBrandName()).trim() || 'NewsNow';
  return `${headline}\n${shareUrl}\n\nBy ${source} via ${brand}.`;
}

function buildSharePayload(post, shareCode, req) {
  const shareUrl = buildShareUrl(shareCode, req);
  const sourceName = publisherNameFromPost(post);
  const shareText = buildShareText({
    title: post.title,
    shareUrl,
    sourceName,
  });
  return {
    shareUrl,
    shareText,
    shareCode,
    sourceName,
    articleUrl: buildArticleUrl(post.id, req),
  };
}

async function resolvePostByShareCode(code) {
  const normalized = String(code || '').trim();
  if (!/^[A-Za-z0-9]{4,12}$/.test(normalized)) return null;
  return prisma.newsPost.findFirst({
    where: { shareCode: normalized, status: 'approved' },
    select: {
      id: true,
      title: true,
      summary: true,
      sourceName: true,
      sourceType: true,
      youtubeChannelTitle: true,
      reporter: { select: { name: true } },
      category: { select: { name: true } },
      media: { take: 1, orderBy: { order: 'asc' }, select: { url: true, thumbnail: true } },
    },
  });
}

module.exports = {
  SHARE_CODE_LEN,
  getShareWebBaseUrl,
  getAppBrandName,
  generateShareCode,
  ensureShareCodeForPost,
  buildShareUrl,
  buildArticleUrl,
  buildShareText,
  buildSharePayload,
  resolvePostByShareCode,
};
