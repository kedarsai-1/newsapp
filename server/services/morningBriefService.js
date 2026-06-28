const { prisma } = require('../config/prisma');
const { ensureShareCodeForPost } = require('../utils/shareLinkService');
const { sendToTopic } = require('../utils/notifications');
const { truncatePushText, NOTIFICATION_BODY_MAX, NOTIFICATION_TITLE_MAX } = require('../utils/pushPolicy');

const BRIEF_TITLES = {
  en: 'Good morning — your news brief',
  hi: 'सुप्रभात — आज की प्रमुख खबरें',
  te: 'శుభోదయం — ఈరోజు ముఖ్య వార్తలు',
};

function requirePublicShareBaseUrl() {
  const configured = process.env.SHARE_WEB_BASE_URL?.trim();
  if (!configured) {
    throw new Error('SHARE_WEB_BASE_URL must be set for morning brief push links');
  }
  const base = configured.replace(/\/$/, '');
  if (/127\.0\.0\.1|localhost/i.test(base)) {
    throw new Error('SHARE_WEB_BASE_URL must be a public URL for morning brief push links');
  }
  return base;
}

async function fetchTopHeadlines(language, { limit = 5, hours = 24 } = {}) {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000);
  return prisma.newsPost.findMany({
    where: {
      status: 'approved',
      language,
      OR: [
        { sourcePublishedAt: { gte: since } },
        { sourcePublishedAt: null, createdAt: { gte: since } },
      ],
    },
    orderBy: [
      { isBreaking: 'desc' },
      { views: 'desc' },
      { sourcePublishedAt: 'desc' },
      { createdAt: 'desc' },
    ],
    take: limit,
    select: {
      id: true,
      title: true,
      shareCode: true,
      isBreaking: true,
    },
  });
}

async function ensureShareCodesForPosts(posts) {
  const enriched = [];
  for (const post of posts) {
    const shareCode = await ensureShareCodeForPost(post.id, post.shareCode);
    enriched.push({ ...post, shareCode });
  }
  return enriched;
}

function buildBriefBody(posts, webBase) {
  if (!posts.length) return '';
  const bullets = posts.map((p, i) => {
    const prefix = p.isBreaking ? '🔴 ' : '';
    return `${i + 1}. ${prefix}${truncatePushText(p.title, 42)}`;
  });
  const first = posts[0];
  const link = `${webBase}/n/${first.shareCode}`;
  const more = posts.length > 1 ? ` · +${posts.length - 1} more` : '';
  const headlineLine = truncatePushText(bullets.join(' · '), NOTIFICATION_BODY_MAX - link.length - more.length - 2);
  return truncatePushText(`${headlineLine}${more}\n${link}`, NOTIFICATION_BODY_MAX);
}

async function sendMorningBriefForLanguage(language) {
  const webBase = requirePublicShareBaseUrl();
  let posts = await fetchTopHeadlines(language);
  if (!posts.length) {
    return { language, sent: false, reason: 'no_posts' };
  }
  posts = await ensureShareCodesForPosts(posts);
  const title = truncatePushText(BRIEF_TITLES[language] || BRIEF_TITLES.en, NOTIFICATION_TITLE_MAX);
  const body = buildBriefBody(posts, webBase);
  const topic = `digest_${language}`;
  const result = await sendToTopic(topic, title, body, {
    type: 'morning_brief',
    language,
    postId: posts[0].id,
    shareUrl: `${webBase}/n/${posts[0].shareCode}`,
  }, { collapseKey: `morning_brief_${language}` });
  return { language, sent: result.success === true, topic, count: posts.length };
}

async function sendMorningBrief() {
  if (process.env.MORNING_BRIEF_ENABLED === 'false') {
    return { skipped: true, reason: 'disabled' };
  }
  const langs = (process.env.MORNING_BRIEF_LANGUAGES || 'en,hi,te')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter((s) => ['en', 'hi', 'te'].includes(s));
  const results = [];
  for (const language of langs) {
    try {
      results.push(await sendMorningBriefForLanguage(language));
    } catch (err) {
      console.error(`[morning-brief] ${language}:`, err.message);
      results.push({ language, sent: false, error: err.message });
    }
  }
  return { success: true, results };
}

module.exports = {
  requirePublicShareBaseUrl,
  fetchTopHeadlines,
  ensureShareCodesForPosts,
  buildBriefBody,
  sendMorningBrief,
  sendMorningBriefForLanguage,
};
