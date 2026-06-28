const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  localFeedSpecificity,
  sortLocalFeedsBySpecificity,
  ingestLocationScore,
} = require('../../services/newsIngestionService');
const { resolveFeedLocation } = require('../../services/districtClassifierService');

describe('local news ingestion helpers', () => {
  it('ranks city local feeds above state-wide AP/TG buckets', () => {
    const feeds = [
      { categorySlug: 'local', politicsScope: 'andhra', name: 'NTV Telugu - Andhra Pradesh' },
      {
        categorySlug: 'local',
        politicsScope: 'andhra',
        locationCity: 'Guntur',
        locationDistrict: 'Guntur',
        name: 'TV9 Telugu - Guntur',
      },
    ];
    const sorted = sortLocalFeedsBySpecificity(feeds);
    assert.equal(sorted[0].name, 'TV9 Telugu - Guntur');
    assert.ok(localFeedSpecificity(sorted[0]) > localFeedSpecificity(sorted[1]));
  });

  it('scores hyperlocal fields higher than state-only rows', () => {
    const hyper = ingestLocationScore({
      locationCity: 'Guntur',
      locationDistrict: 'Guntur',
      locationState: 'Andhra Pradesh',
    });
    const broad = ingestLocationScore({ locationState: 'Andhra Pradesh' });
    assert.ok(hyper > broad);
  });

  it('resolveFeedLocation sets AP state for andhra scope feeds', () => {
    const loc = resolveFeedLocation({ categorySlug: 'local', politicsScope: 'andhra' });
    assert.equal(loc.locationState, 'Andhra Pradesh');
    assert.equal(loc.locationDistrict, null);
  });
});
