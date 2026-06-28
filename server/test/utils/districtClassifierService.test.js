const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  mapTextToDistrict,
  resolveFeedLocation,
  CITY_TO_DISTRICT,
} = require('../../services/districtClassifierService');
const {
  inferHindiPoliticsScope,
  politicsScopeToState,
} = require('../../config/hindiRegionalScopes');
const { politicsScopeWhere } = require('../../controllers/newsController');

describe('districtClassifierService', () => {
  it('maps Vizag mentions to Visakhapatnam district', () => {
    assert.equal(mapTextToDistrict('Fire in Vizag market injures two'), 'Visakhapatnam');
  });

  it('maps Vijayawada mentions to NTR district', () => {
    assert.equal(mapTextToDistrict('Vijayawada civic body announces new tax'), 'NTR');
  });

  it('resolves feed city to district when district omitted', () => {
    const loc = resolveFeedLocation({
      locationCity: 'Hyderabad',
      politicsScope: 'telangana',
    });
    assert.equal(loc.locationDistrict, 'Hyderabad');
    assert.equal(loc.locationState, 'Telangana');
  });

  it('maps known cities via CITY_TO_DISTRICT', () => {
    assert.equal(CITY_TO_DISTRICT.Rajahmundry, 'East Godavari');
  });

  it('maps Lucknow mentions to Lucknow district', () => {
    assert.equal(mapTextToDistrict('Lucknow metro extension approved'), 'Lucknow');
  });

  it('resolves Hindi UP feed scope to Uttar Pradesh state', () => {
    const loc = resolveFeedLocation({
      politicsScope: 'up',
      locationCity: 'Kanpur',
      locationDistrict: 'Kanpur',
    });
    assert.equal(loc.locationState, 'Uttar Pradesh');
  });
});

describe('hindiRegionalScopes', () => {
  it('infers UP scope from Hindi headline', () => {
    assert.equal(inferHindiPoliticsScope('योगी आदित्यनाथ ने लखनऊ में घोषणा की', ''), 'up');
  });

  it('maps politics scope to state name', () => {
    assert.equal(politicsScopeToState('bihar'), 'Bihar');
    assert.equal(politicsScopeToState('delhi'), 'Delhi');
  });
});

describe('politicsScopeWhere hindi', () => {
  it('builds UP scope filter clause', () => {
    const clause = politicsScopeWhere('up', 'hi');
    assert.ok(clause);
    assert.ok(clause.OR);
  });
});
