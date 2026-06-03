const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isPoliticalShortContent,
  filterPostsForShortsFeed,
} = require('../../utils/shortsFeedFilter');

describe('shortsFeedFilter', () => {
  it('rejects classified political interview videos', () => {
    assert.equal(
      isPoliticalShortContent({
        title: 'CM exclusive interview on election strategy',
        body: 'minister speaks about parliament session',
        videoCategory: 'political interview',
        language: 'en',
      }),
      true,
    );
  });

  it('rejects politics category YouTube rows', () => {
    assert.equal(
      isPoliticalShortContent({
        title: 'Daily update',
        category: { slug: 'politics' },
        language: 'te',
      }),
      true,
    );
  });

  it('allows entertainment shorts', () => {
    assert.equal(
      isPoliticalShortContent({
        title: 'Peddi trailer: Ram Charan pan-India drama',
        body: 'movie teaser release today',
        category: { slug: 'entertainment' },
        language: 'te',
      }),
      false,
    );
  });

  it('filterPostsForShortsFeed drops political rows', () => {
    const out = filterPostsForShortsFeed([
      { title: 'Funny clip', category: { slug: 'entertainment' }, language: 'en' },
      {
        title: 'Minister press meet on cabinet',
        body: 'election rally speech',
        category: { slug: 'politics' },
        language: 'hi',
      },
    ]);
    assert.equal(out.length, 1);
    assert.equal(out[0].category.slug, 'entertainment');
  });
});
