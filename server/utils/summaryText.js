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
const PAGE_CHROME_PREFIX = /^(?:(?:UK|US|India|World|Sport|Sports|Business|Tech)\s+)?Edition\s*/i;
const PAGE_CHROME_LEAD = /^(?:Report|Live|Updated|Breaking|Watch|Listen|Video|Gallery|In pictures)\s*/i;
const IMAGE_CREDIT_LINE = /\b(?:Getty Images|PA Media|Reuters|AFP|AP Photo|Shutterstock|Alamy)\b[^.!?]*[.!?]?/gi;
const BOILERPLATE_FRAGMENT = /\b(?:subscribe|follow us|share this|download (?:the )?app|click here|read more)\b/gi;

/** Fix words glued by stripped HTML (e.g. runsReport, GLSomerset). */
function fixConcatenatedWords(text) {
  return String(text || '')
    .replace(/([A-Z]{2,})([A-Z][a-z])/g, '$1 $2')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/([a-zA-Z])(\d)/g, '$1 $2')
    .replace(/(\d)([a-zA-Z])/g, '$1 $2')
    .replace(/([.!?])([A-Z])/g, '$1 $2')
    .replace(/([a-z])(Report|Live|Edition)\b/g, '$1 $2');
}

function stripPageChrome(text) {
  let x = String(text || '').trim();
  if (!x) return '';
  for (let i = 0; i < 4; i += 1) {
    const next = x
      .replace(PAGE_CHROME_PREFIX, '')
      .replace(PAGE_CHROME_LEAD, '')
      .trim();
    if (next === x) break;
    x = next;
  }
  return x;
}

function normalizeSummarySource(text) {
  let x = String(text || '')
    .replace(/[\u200B-\u200D\uFEFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!x) return '';

  x = x.replace(/https?:\/\/\S+/gi, ' ');
  x = x.replace(/(?:#\S+\s*){4,}/g, ' ');
  x = x.replace(/#(\S+)/g, '$1');
  x = fixConcatenatedWords(x);
  x = stripPageChrome(x);
  x = x.replace(IMAGE_CREDIT_LINE, ' ');
  x = x.replace(BOILERPLATE_FRAGMENT, ' ');
  return x.replace(/\s+/g, ' ').trim();
}

/**
 * Full plain-text cleanup for RSS/API ingest and extractive summaries.
 * @param {string} text
 * @param {{ stripHtml?: boolean }} [options]
 * @returns {string}
 */
function cleanArticlePlainText(text, { stripHtml = false } = {}) {
  let x = String(text || '');
  if (stripHtml) {
    x = x
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<\/(p|div|h[1-6]|li|tr|td|th|section|article|blockquote)>/gi, ' ')
      .replace(/<(br|hr)\s*\/?>/gi, ' ')
      .replace(/<[^>]*>/g, ' ');
  }
  return normalizeSummarySource(x);
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
  cleanArticlePlainText,
  fixConcatenatedWords,
  stripPageChrome,
  truncateSummary,
  clipSummaryForStorage,
  clipSummaryForSnippet,
  isSuspiciousSummary,
};
