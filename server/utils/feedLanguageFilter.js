/**
 * Prisma language clause for feed/sports queries (ISO 639-1 + legacy franc tags).
 * @param {string|null|undefined} langParam - e.g. en, te, hi; null = no filter
 */
function buildLanguageClause(langParam) {
  if (!langParam) return null;
  const lang = String(langParam).toLowerCase();
  if (lang === 'en') {
    return { language: 'en' };
  }
  if (lang === 'te') {
    return {
      OR: [
        { language: 'te' },
        { originalLanguage: 'tel' },
        {
          sourceName:
            { contains: 'telugu', mode: 'insensitive' },
        },
      ],
    };
  }
  if (lang === 'hi') {
    return {
      OR: [
        { language: 'hi' },
        { originalLanguage: 'hin' },
        {
          sourceName:
            { contains: 'hindi', mode: 'insensitive' },
        },
      ],
    };
  }
  return { language: lang };
}

/** Apply language filter to a base Prisma where object. */
function applyLanguageFilter(query, langParam) {
  const clause = buildLanguageClause(langParam);
  if (!clause) return query;
  const next = { ...query };
  next.AND = [...(next.AND || []), clause];
  return next;
}

module.exports = { buildLanguageClause, applyLanguageFilter };
