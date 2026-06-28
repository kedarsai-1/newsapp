const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { newsPostDataFromDoc } = require('../../utils/prismaNewsPost');

describe('newsPostDataFromDoc location fields', () => {
  it('persists flat location fields from RSS ingest docs', () => {
    const data = newsPostDataFromDoc({
      title: 'Local headline',
      body: 'Body',
      reporterId: '00000000-0000-0000-0000-000000000001',
      categoryId: '00000000-0000-0000-0000-000000000002',
      locationCity: 'Hyderabad',
      locationDistrict: 'Hyderabad',
      locationMandal: 'Secunderabad',
      locationState: 'Telangana',
      locationLatitude: 17.385,
      locationLongitude: 78.4867,
      locationCountry: 'India',
    });
    assert.equal(data.locationCity, 'Hyderabad');
    assert.equal(data.locationDistrict, 'Hyderabad');
    assert.equal(data.locationMandal, 'Secunderabad');
    assert.equal(data.locationState, 'Telangana');
    assert.equal(data.locationLatitude, 17.385);
    assert.equal(data.locationLongitude, 78.4867);
  });

  it('flat fields override nested location object', () => {
    const data = newsPostDataFromDoc({
      title: 'T',
      body: 'B',
      reporterId: '00000000-0000-0000-0000-000000000001',
      categoryId: '00000000-0000-0000-0000-000000000002',
      location: { city: 'OldCity', state: 'OldState', latitude: 1, longitude: 2 },
      locationCity: 'Lucknow',
      locationDistrict: 'Lucknow',
      locationState: 'Uttar Pradesh',
    });
    assert.equal(data.locationCity, 'Lucknow');
    assert.equal(data.locationDistrict, 'Lucknow');
    assert.equal(data.locationState, 'Uttar Pradesh');
    assert.equal(data.locationLatitude, 1);
    assert.equal(data.locationLongitude, 2);
  });
});
