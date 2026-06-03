const { POLITICAL_LABELS } = require('../config/politicalVideoConfig');
const { classifyByKeywords } = require('./politicalKeywordFilter');
const { isTeluguPoliticalStory, isHindiPoliticalStory } = require('./politicalStoryFilter');

/** True when a YouTube row should never appear in the main Shorts tab. */
function isPoliticalShortContent(postLike) {
  const videoCat = String(postLike?.videoCategory || '').toLowerCase();
  if (POLITICAL_LABELS.includes(videoCat)) return true;

  const catSlug = String(
    postLike?.category?.slug || postLike?.categorySlug || '',
  ).toLowerCase();
  if (catSlug === 'politics' || catSlug === 'local') return true;

  const tags = Array.isArray(postLike?.tags) ? postLike.tags : [];
  if (tags.some((t) => /politic/i.test(String(t)))) return true;

  const scope = String(postLike?.politicsScope || '').toLowerCase();
  if (scope && scope !== 'all') return true;

  const lang = String(postLike?.language || 'en').toLowerCase();
  if (lang === 'te' && isTeluguPoliticalStory(postLike)) return true;
  if (lang === 'hi' && isHindiPoliticalStory(postLike)) return true;

  const kw = classifyByKeywords({
    title: postLike?.title,
    description: postLike?.body || postLike?.summary,
    language: lang,
  });
  // Strict: one political keyword signal is enough for Shorts exclusion.
  if (kw.stage === 'accept' || kw.stage === 'uncertain') return true;

  return false;
}

async function getShortsExcludeCategoryIds(prismaClient) {
  const cats = await prismaClient.category.findMany({
    where: { slug: { in: ['politics', 'local'] }, isActive: true },
    select: { id: true },
  });
  return cats.map((c) => c.id);
}

function prismaShortsExcludePoliticsClause(excludeCategoryIds = []) {
  const clauses = [
    {
      OR: [
        { videoCategory: null },
        { videoCategory: { notIn: POLITICAL_LABELS } },
      ],
    },
  ];
  if (excludeCategoryIds.length) {
    clauses.push({ categoryId: { notIn: excludeCategoryIds } });
  }
  return { AND: clauses };
}

function filterPostsForShortsFeed(posts) {
  if (process.env.SHORTS_STRICT_NO_POLITICS === 'false') return posts;
  return (posts || []).filter((p) => !isPoliticalShortContent(p));
}

module.exports = {
  isPoliticalShortContent,
  getShortsExcludeCategoryIds,
  prismaShortsExcludePoliticsClause,
  filterPostsForShortsFeed,
};
