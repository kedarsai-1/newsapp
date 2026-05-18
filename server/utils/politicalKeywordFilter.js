const {
  POLITICAL_KEYWORDS,
  BLACKLIST_KEYWORDS,
  KEYWORD_LABEL_HINTS,
  POLITICAL_LABELS,
} = require('../config/politicalVideoConfig');

function normalizeText(title, description) {
  return `${title || ''} ${description || ''}`.replace(/\s+/g, ' ').trim();
}

function countMatches(text, keywords) {
  const lower = text.toLowerCase();
  let hits = 0;
  for (const kw of keywords) {
    const k = String(kw).toLowerCase();
    if (k.length < 2) continue;
    if (lower.includes(k)) hits += 1;
  }
  return hits;
}

function detectLanguage(text) {
  if (/[\u0C00-\u0C7F]/.test(text)) return 'te';
  if (/[\u0900-\u097F]/.test(text)) return 'hi';
  return 'en';
}

function inferLabelFromKeywords(text) {
  for (const hint of KEYWORD_LABEL_HINTS) {
    if (hint.pattern.test(text)) return hint.label;
  }
  return 'political interview';
}

/**
 * @returns {'reject'|'accept'|'uncertain', object}
 */
function classifyByKeywords(video) {
  const text = normalizeText(video.title, video.description);
  if (!text || text.length < 8) {
    return { stage: 'reject', reason: 'empty_text' };
  }

  const blacklistHits = countMatches(text, BLACKLIST_KEYWORDS);
  if (blacklistHits > 0) {
    return { stage: 'reject', reason: 'blacklist', blacklistHits };
  }

  const enHits = countMatches(text, POLITICAL_KEYWORDS.en);
  const teHits = countMatches(text, POLITICAL_KEYWORDS.te);
  const hiHits = countMatches(text, POLITICAL_KEYWORDS.hi);
  const totalPolitical = enHits + teHits + hiHits;

  const language =
    video.language
    || (teHits >= hiHits && teHits >= enHits && teHits > 0
      ? 'te'
      : hiHits >= enHits && hiHits > 0
        ? 'hi'
        : detectLanguage(text));

  if (totalPolitical >= 2) {
    return {
      stage: 'accept',
      method: 'keyword',
      language,
      category: inferLabelFromKeywords(text),
      confidence: Math.min(0.95, 0.55 + totalPolitical * 0.08),
      politicalHits: totalPolitical,
    };
  }

  if (totalPolitical === 1) {
    return {
      stage: 'uncertain',
      language,
      politicalHits: 1,
    };
  }

  return { stage: 'reject', reason: 'no_political_keywords' };
}

function isPoliticalLabel(label) {
  return POLITICAL_LABELS.includes(String(label || '').toLowerCase());
}

module.exports = {
  classifyByKeywords,
  isPoliticalLabel,
  normalizeText,
  detectLanguage,
};
