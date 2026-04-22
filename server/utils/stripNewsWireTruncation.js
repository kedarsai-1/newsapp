/**
 * NewsAPI (and similar wires) append a footer when the article body is truncated, e.g.
 *   "... end of excerpt [+1909 chars]" or "[1909 chars]"
 * Strip these so they never show in the app UI.
 */
function stripNewsWireTruncationMarkers(text) {
  if (text == null) return text;
  return String(text)
    .replace(/\[\+\d+\s*chars\]/gi, '')
    .replace(/\[\d+\s*chars\]/gi, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

module.exports = { stripNewsWireTruncationMarkers };
