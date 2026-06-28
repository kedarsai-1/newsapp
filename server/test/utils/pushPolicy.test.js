const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  shouldNotifyFeedIngest,
  buildIngestNotification,
  truncatePushText,
  sanitizeFcmTopic,
  isInvalidFcmTokenError,
  normalizeIngestSource,
  parsePushIngestSources,
} = require('../../utils/pushPolicy');

describe('pushPolicy', () => {
  it('requires minimum inserted count', () => {
    const result = shouldNotifyFeedIngest({
      inserted: 2,
      minInserted: 5,
      notifyEnabled: true,
      allowedSources: new Set(['news']),
    });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'below_min_inserted');
  });

  it('respects ingest source allowlist', () => {
    const result = shouldNotifyFeedIngest({
      inserted: 10,
      source: 'youtube',
      minInserted: 1,
      notifyEnabled: true,
      allowedSources: new Set(['news']),
    });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'source_excluded');
  });

  it('allows news ingest when thresholds pass', () => {
    const result = shouldNotifyFeedIngest({
      inserted: 8,
      source: 'news',
      minInserted: 5,
      cooldownMs: 60000,
      lastPushAt: 0,
      now: 1000,
      notifyEnabled: true,
      allowedSources: new Set(['news']),
    });
    assert.equal(result.ok, true);
    assert.equal(result.count, 8);
  });

  it('blocks ingest push during cooldown window', () => {
    const result = shouldNotifyFeedIngest({
      inserted: 10,
      source: 'news',
      minInserted: 1,
      cooldownMs: 900000,
      lastPushAt: 500000,
      now: 600000,
      notifyEnabled: true,
      allowedSources: new Set(['news']),
    });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'cooldown');
  });

  it('builds singular and plural ingest copy', () => {
    assert.match(buildIngestNotification(1).title, /New story/i);
    assert.match(buildIngestNotification(4).body, /4 new stories/i);
  });

  it('uses article headline as notification title when provided', () => {
    const one = buildIngestNotification(1, { headline: 'Election results announced' });
    assert.equal(one.title, 'Election results announced');
    assert.match(one.body, /Tap to read/i);

    const many = buildIngestNotification(5, { headline: 'Market hits record high' });
    assert.equal(many.title, 'Market hits record high');
    assert.match(many.body, /4 more new stories/i);
  });

  it('truncates long notification text', () => {
    const long = 'x'.repeat(300);
    const out = truncatePushText(long, 240);
    assert.equal(out.length, 240);
    assert.match(out, /…$/);
  });

  it('sanitizes topic names for FCM', () => {
    assert.equal(sanitizeFcmTopic('category_sports.news'), 'category_sports_news');
  });

  it('detects invalid FCM token errors', () => {
    assert.equal(
      isInvalidFcmTokenError({ code: 'messaging/registration-token-not-registered' }),
      true,
    );
    assert.equal(isInvalidFcmTokenError({ message: 'Requested entity was not found.' }), false);
  });

  it('normalizes political video ingest source', () => {
    assert.equal(normalizeIngestSource('political-video'), 'political-video');
    assert.equal(normalizeIngestSource(''), 'news');
  });

  it('defaults ingest sources to news', () => {
    const prev = process.env.PUSH_INGEST_SOURCES;
    delete process.env.PUSH_INGEST_SOURCES;
    assert.deepEqual([...parsePushIngestSources()], ['news']);
    process.env.PUSH_INGEST_SOURCES = prev;
  });
});
