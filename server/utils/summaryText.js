/**
 * Normalize raw text before summarization (YouTube descriptions, wire copy, etc.).
 * @param {string} text
 * @returns {string}
 */
function normalizeSummarySource(text) {
  let x = String(text || '')
    .replace(/[\u200B-\u200D\uFEFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!x) return '';

  // Strip URLs (common in YouTube descriptions).
  x = x.replace(/https?:\/\/\S+/gi, ' ');

  // Long hashtag runs (common on YouTube) — drop the tag block, keep prose.
  x = x.replace(/(?:#\S+\s*){4,}/g, ' ');
  // Individual hashtags → plain words so truncation can land on boundaries.
  x = x.replace(/#(\S+)/g, '$1');
  return x.replace(/\s+/g, ' ').trim();
}

/**
 * Truncate feed summaries at sentence or word boundaries (never mid-word).
 * @param {string} text
 * @param {number} max
 * @returns {string}
 */
function truncateSummary(text, max = 300) {
  const x = normalizeSummarySource(text);
  if (!x) return '';
  if (x.length <= max) return x;

  const cut = x.slice(0, max);
  const minSentence = Math.floor(max * 0.35);
  const lastSentEnd = Math.max(
    cut.lastIndexOf('. '),
    cut.lastIndexOf('। '),
    cut.lastIndexOf('? '),
    cut.lastIndexOf('! '),
  );
  if (lastSentEnd >= minSentence) {
    return cut.slice(0, lastSentEnd + 1).trim();
  }

  const minWord = Math.floor(max * 0.5);
  const sp = cut.lastIndexOf(' ');
  if (sp >= minWord) {
    return `${cut.slice(0, sp).trim()}…`;
  }

  const comma = cut.lastIndexOf(', ');
  if (comma >= minWord) {
    return `${cut.slice(0, comma).trim()}…`;
  }

  return `${cut.slice(0, max - 1).trim()}…`;
}

/** True when summary likely ends mid-word (legacy hard-slice artifact). */
function isSuspiciousSummary(summary) {
  const s = String(summary || '').trim();
  if (!s || s.length < 200) return false;
  if (/[.!?।…]$/.test(s)) return false;
  if (s.endsWith('...')) return true;
  return s.length >= 275 && /[a-zA-Z]{1,4}$/.test(s);
}

module.exports = {
  normalizeSummarySource,
  truncateSummary,
  isSuspiciousSummary,
};
