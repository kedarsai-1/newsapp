const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  cleanArticlePlainText,
  fixConcatenatedWords,
  stripPageChrome,
} = require('../../utils/summaryText');
const { extractiveSummaryNative } = require('../../services/rssService');

describe('summaryText cleaning', () => {
  it('fixes glued words from stripped HTML', () => {
    const raw = 'Edition GLSomerset won by 306 runsReportO\'Neill resists late fightback';
    const clean = cleanArticlePlainText(raw);
    assert.match(clean, /GL Somerset/i);
    assert.match(clean, /runs Report/i);
    assert.doesNotMatch(clean, /^Edition/i);
  });

  it('strips page chrome prefixes', () => {
    assert.equal(stripPageChrome('UK Edition Somerset beat Essex'), 'Somerset beat Essex');
    assert.equal(stripPageChrome('Report India win the series'), 'India win the series');
  });

  it('inserts spaces between camelCase fragments', () => {
    assert.equal(fixConcatenatedWords('runsReportLive'), 'runs Report Live');
  });

  it('removes HTML and normalizes whitespace', () => {
    const html = '<p>Edition</p><div>Somerset <b>won</b> by 306 runs.</div>';
    const clean = cleanArticlePlainText(html, { stripHtml: true });
    assert.match(clean, /Somerset won by 306 runs/);
    assert.doesNotMatch(clean, /Edition/i);
  });
});

describe('extractiveSummaryNative', () => {
  it('prefers real sentences over page chrome', () => {
    const raw = (
      'Edition GLSomerset won by 306 runs. '
      + 'Report O\'Neill hit a century as Somerset sealed victory at Taunton.'
    );
    const out = extractiveSummaryNative(raw);
    assert.match(out, /Somerset/i);
    assert.match(out, /306 runs|O'Neill|Taunton/i);
    assert.doesNotMatch(out, /^Edition/i);
  });
});
