const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { inferPoliticsScope } = require('../../services/politicalVideoIngestionService');

describe('inferPoliticsScope', () => {
  it('correctly classifies international scope from title or description keywords', () => {
    assert.equal(inferPoliticsScope('Biden talks with Putin about Ukraine', ''), 'international');
    assert.equal(inferPoliticsScope('Israel and Gaza conflict updates', ''), 'international');
    assert.equal(inferPoliticsScope('Global climate summit updates', 'Discussion on international treaties'), 'international');
  });

  it('correctly classifies Andhra Pradesh regional politics', () => {
    assert.equal(inferPoliticsScope('AP Election results live: YSRCP vs TDP', ''), 'andhra');
    assert.equal(inferPoliticsScope('Jagan Mohan Reddy speech in Visakhapatnam', 'TDP leaders meet in Amaravati'), 'andhra');
    assert.equal(inferPoliticsScope('ఆంధ్ర ప్రదేశ్ ఎన్నికల వార్తలు', ''), 'andhra');
  });

  it('correctly classifies Telangana regional politics', () => {
    assert.equal(inferPoliticsScope('KCR press meet in Hyderabad live', ''), 'telangana');
    assert.equal(inferPoliticsScope('Revanth Reddy sworn in as Telangana CM', 'BRS party response'), 'telangana');
    assert.equal(inferPoliticsScope('తెలంగాణ అసెంబ్లీ సమావేశాలు', ''), 'telangana');
  });

  it('correctly classifies North Indian regional politics', () => {
    assert.equal(inferPoliticsScope('Yogi Adityanath rally in Uttar Pradesh', ''), 'north');
    assert.equal(inferPoliticsScope('Kejriwal press conference in Delhi', 'Delhi government announcements'), 'north');
    assert.equal(inferPoliticsScope('उत्तर प्रदेश सरकार का बड़ा फैसला', ''), 'north');
  });

  it('ignores boilerplate domain links in description to avoid false positives', () => {
    // Standard TV9 or Sakshi description containing social links with "andhra" or "telangana"
    const description = `
      Subscribe to our channel: https://youtube.com/sakshinews
      Like us on Facebook: https://facebook.com/sakshinews
      Follow us on Twitter: https://twitter.com/sakshinews
      Visit Sakshi Andhra/Telangana News website: https://andhrajyothy.com/telangana
    `;
    assert.equal(inferPoliticsScope('National debate on Budget 2026', description), 'india');
  });

  it('defaults to india for national politics scope', () => {
    assert.equal(inferPoliticsScope('Modi speaks on national security', 'BJP government budget'), 'india');
  });
});
