const { describe, it, before } = require('node:test');
const assert = require('node:assert/strict');
const {
  mapTextToMandal,
  primeMandalCache,
} = require('../../services/mandalClassifierService');

describe('mandalClassifierService', () => {
  before(() => {
    primeMandalCache([
      {
        name: 'Guntur',
        slug: 'guntur',
        district: 'Guntur',
        state: 'Andhra Pradesh',
        aliases: ['guntur city'],
      },
      {
        name: 'Tenali',
        slug: 'tenali',
        district: 'Guntur',
        state: 'Andhra Pradesh',
        aliases: [],
      },
    ]);
  });

  it('maps headline text to mandal when district matches', () => {
    const hit = mapTextToMandal('Tenali market fire under control', {
      districtHint: 'Guntur',
      stateHint: 'Andhra Pradesh',
    });
    assert.equal(hit?.mandal, 'Tenali');
  });

  it('falls back to any mandal mention without district hint', () => {
    const hit = mapTextToMandal('Police raid in Guntur city market');
    assert.equal(hit?.mandal, 'Guntur');
  });
});
