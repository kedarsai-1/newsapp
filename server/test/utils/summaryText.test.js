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

  it('keeps multiple sentences for long indic articles (not just the lede)', () => {
    const raw = (
      'లేపాక్షి ఆలయం పేరు వినగానే వేలాడే స్తంభం గుర్తుకు వస్తుంది. '
      + 'ఆంధ్రప్రదేశ్లోని శ్రీ సత్యసాయి జిల్లాలో ఈ విజయనగర కాలం నాటి ఆలయం ప్రసిద్ధి చెందింది. '
      + 'ప్రతి సంవత్సరం వేలాది మంది భక్తులు ఈ ఆలయాన్ని సందర్శిస్తారు. '
      + 'ఆలయంలోని ఒక స్తంభం నేలను పూర్తిగా తాకకుండా కనిపిస్తుంది. '
      + 'కాగితం లేదా వస్త్రాన్ని సులభంగా తీసుకెళ్లవచ్చని సందర్శకులు చూపిస్తారు. '
      + 'బ్రిటిష్ కాలంలో స్తంభాన్ని కదిలించే ప్రయత్నం జరిగినట్లు ఒక కథ ఉంది. '
      + 'విజయనగర కాలంలో వీరన్న, విరూపన్నల ఆధ్వర్యంలో నిర్మించినట్లు చరిత్ర చెబుతోంది.'
    );
    const out = extractiveSummaryNative(raw);
    assert.ok(out.length >= 400, `expected richer extractive summary, got ${out.length} chars`);
    assert.match(out, /కాగితం|వస్త్ర/i);
    assert.match(out, /బ్రిటిష్/i);
  });
});
