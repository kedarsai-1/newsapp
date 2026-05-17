/**
 * MongoDB language clause for feed/sports queries (ISO 639-1 + legacy franc tags).
 * @param {string|null|undefined} langParam - e.g. en, te, hi; null = no filter
 */
function buildLanguageClause(langParam) {
  if (!langParam) return null;
  const lang = String(langParam).toLowerCase();
  if (lang === 'en') {
    return {
      $or: [
        { language: 'en' },
        { language: { $exists: false } },
        { language: null },
      ],
    };
  }
  if (lang === 'te') {
    return {
      $or: [
        { language: 'te' },
        { originalLanguage: 'tel' },
        {
          sourceName:
            /eenadu|sakshi|tv9\s*telugu|tv9telugu|123telugu|mana\s*telangana|andhra\s*jyothy|v6\s*velugu|10tv|ntv\s*telugu|ntvtelugu/i,
        },
      ],
    };
  }
  if (lang === 'hi') {
    return {
      $or: [
        { language: 'hi' },
        { originalLanguage: 'hin' },
        {
          sourceName:
            /news18\s*hindi|hindi\.news18|amar\s*ujala|amarujala|dainik\s*bhaskar|bhaskar\.com|jagran|abp\s*news|abplive/i,
        },
      ],
    };
  }
  return { language: lang };
}

/** Apply language filter to a base Mongo query object. */
function applyLanguageFilter(query, langParam) {
  const clause = buildLanguageClause(langParam);
  if (!clause) return query;
  const next = { ...query };
  next.$and = [...(next.$and || []), clause];
  return next;
}

module.exports = { buildLanguageClause, applyLanguageFilter };
