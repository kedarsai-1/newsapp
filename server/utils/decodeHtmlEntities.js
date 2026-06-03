/**
 * Decode HTML entities and strip common RSS/HTML noise before AI or client display.
 */
const NAMED_ENTITIES = {
  nbsp: ' ',
  amp: '&',
  quot: '"',
  apos: "'",
  lt: '<',
  gt: '>',
  zwnj: '',
  zwj: '',
  lrm: '',
  rlm: '',
  ndash: '-',
  mdash: '-',
  lsquo: '\u2018',
  rsquo: '\u2019',
  ldquo: '\u201C',
  rdquo: '\u201D',
  hellip: '…',
};

function isAllowedControlCodepoint(code) {
  return code === 0x09 || code === 0x0a || code === 0x0d;
}

function isDisallowedControlCodepoint(code) {
  if (isAllowedControlCodepoint(code)) return false;
  // C0: U+0000–U+001F, C1: U+007F–U+009F
  return (code >= 0x00 && code <= 0x1f) || (code >= 0x7f && code <= 0x9f);
}

function decodeNumericEntity(num, base) {
  const code = parseInt(num, base);
  if (!Number.isFinite(code) || code < 0 || code > 0x10FFFF) return '';
  if (isDisallowedControlCodepoint(code)) return '';
  try {
    return String.fromCodePoint(code);
  } catch {
    return '';
  }
}

function decodeHtmlEntities(input) {
  let t = String(input || '');
  if (!t) return '';

  t = t
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => decodeNumericEntity(hex, 16))
    .replace(/&#(\d+);/g, (_, dec) => decodeNumericEntity(dec, 10))
    .replace(/&([a-z]+);/gi, (match, name) => {
      const key = name.toLowerCase();
      if (Object.prototype.hasOwnProperty.call(NAMED_ENTITIES, key)) {
        return NAMED_ENTITIES[key];
      }
      return match;
    });

  return t
    .replace(/caption\s+of\s+image\.?/gi, ' ')
    .replace(/read\s+more\.?/gi, ' ')
    .replace(/click\s+here\.?/gi, ' ')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

module.exports = { decodeHtmlEntities };
