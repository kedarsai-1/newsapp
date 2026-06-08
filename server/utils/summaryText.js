/** Storage vs feed-snippet limits for AI/RSS summaries (detail view uses stored summary). */

const SUMMARY_STORAGE_MAX_CHARS = Math.min(
  10_000,
  Math.max(500, Number(process.env.SUMMARY_STORAGE_MAX_CHARS || 2000)),
);

const SUMMARY_SNIPPET_MAX_CHARS = Math.min(
  SUMMARY_STORAGE_MAX_CHARS,
  Math.max(120, Number(process.env.SUMMARY_SNIPPET_MAX_CHARS || 300)),
);

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

  x = x.replace(/https?:\/\/\S+/gi, ' ');
  x = x.replace(/(?:#\S+\s*){4,}/g, ' ');
  x = x.replace(/#(\S+)/g, '$1');
  return x.replace(/\s+/g, ' ').trim();
}

/**
 * Truncate at sentence or word boundaries (never mid-word).
 * @param {string} text
 * @param {number} max
 * @returns {string}
 */
function truncateSummary(text, max = SUMMARY_SNIPPET_MAX_CHARS) {
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

/** Full summary persisted for article detail (word-aware cap). */
function clipSummaryForStorage(s) {
  return truncateSummary(s, SUMMARY_STORAGE_MAX_CHARS);
}

/** Short snippet for feed cards / API wire descriptions. */
function clipSummaryForSnippet(s) {
  return truncateSummary(s, SUMMARY_SNIPPET_MAX_CHARS);
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
  SUMMARY_STORAGE_MAX_CHARS,
  SUMMARY_SNIPPET_MAX_CHARS,
  normalizeSummarySource,
  truncateSummary,
  clipSummaryForStorage,
  clipSummaryForSnippet,
  isSuspiciousSummary,
};
