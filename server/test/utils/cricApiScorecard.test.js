const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { normalizeMatchSummary } = require('../../services/cricApiService');

describe('cricApiService scorecard fallbacks', () => {
  it('normalizeMatchSummary includes team scores from score array', () => {
    const summary = normalizeMatchSummary({
      id: 'test-1',
      teams: ['Netherlands', 'United States of America'],
      score: [
        { inning: 'Netherlands Inning 1', r: 120, w: 3, o: 18.2 },
        { inning: 'United States of America Inning 1', r: 95, w: 5, o: 16 },
      ],
      status: 'Netherlands need 12 runs',
      matchStarted: true,
      matchEnded: false,
    });
    assert.equal(summary.teams.length, 2);
    assert.equal(summary.teams[0].score, '120/3');
    assert.equal(summary.status, 'live');
  });
});
