const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  matchesFeedCategory,
  passesIngestCategoryGate,
  isSectionSpecificSource,
} = require('../../utils/categoryRelevance');

describe('categoryRelevance — agriculture, education, crime', () => {
  it('recognizes section-specific agriculture feed URLs', () => {
    assert.equal(
      isSectionSpecificSource(
        'agriculture',
        'https://www.thehindu.com/business/agri-business/feeder/default.rss',
        '',
      ),
      true,
    );
    assert.equal(
      isSectionSpecificSource(
        'agriculture',
        'https://www.amarujala.com/rss/agriculture.xml',
        '',
      ),
      true,
    );
    assert.equal(
      isSectionSpecificSource(
        'agriculture',
        'https://www.ntvtelugu.com/category/agriculture/feed',
        '',
      ),
      true,
    );
  });

  it('recognizes education and crime section feeds', () => {
    assert.equal(
      isSectionSpecificSource(
        'education',
        'https://www.ntvtelugu.com/category/education/feed',
        '',
      ),
      true,
    );
    assert.equal(
      isSectionSpecificSource(
        'crime',
        'https://www.amarujala.com/rss/crime.xml',
        '',
      ),
      true,
    );
  });

  it('passes agriculture items from dedicated feeds', () => {
    const item = {
      title: 'MSP hike for wheat farmers',
      summary: 'Government announces support price for crops',
      link: 'https://example.com/agriculture/wheat-msp',
    };
    assert.equal(
      matchesFeedCategory(item, 'agriculture', {
        feedUrl: 'https://www.thehindu.com/business/agri-business/feeder/default.rss',
      }),
      true,
    );
    assert.equal(passesIngestCategoryGate(item, 'agriculture', {
      feedUrl: 'https://www.thehindu.com/business/agri-business/feeder/default.rss',
    }), true);
  });

  it('rejects off-topic crime stories on agriculture section feeds', () => {
    const item = {
      title: 'Harasses Woman: యువతిని బస్సులో లైంగికంగా వేధించిన యువకుడు',
      summary: 'crime against women viral video',
      sourceUrl: 'https://ntvtelugu.com/news/young-man-harasses-woman-on-bus.html',
    };
    assert.equal(
      passesIngestCategoryGate(item, 'agriculture', {
        feedUrl: 'https://www.ntvtelugu.com/category/agriculture/feed',
      }),
      false,
    );
  });

  it('rejects cricket stories mis-tagged as education', () => {
    const item = {
      title: 'IPL 2026: Mumbai Indians win',
      summary: 'Cricket match report',
      link: 'https://example.com/education/ipl',
    };
    assert.equal(passesIngestCategoryGate(item, 'education', {
      feedUrl: 'https://www.ntvtelugu.com/category/education/feed',
    }), false);
  });
});
