const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeFcmData,
  getPushHealth,
  notifyFeedIngestion,
  resetIngestPushCooldownForTests,
} = require('../../utils/notifications');

describe('notifications', () => {
  const envBackup = {};

  beforeEach(() => {
    envBackup.FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
    envBackup.FIREBASE_CLIENT_EMAIL = process.env.FIREBASE_CLIENT_EMAIL;
    envBackup.FIREBASE_PRIVATE_KEY = process.env.FIREBASE_PRIVATE_KEY;
    envBackup.PUSH_NOTIFY_ON_INGEST = process.env.PUSH_NOTIFY_ON_INGEST;
    envBackup.PUSH_MIN_INSERTED = process.env.PUSH_MIN_INSERTED;
    envBackup.PUSH_INGEST_SOURCES = process.env.PUSH_INGEST_SOURCES;
    delete process.env.FIREBASE_PROJECT_ID;
    delete process.env.FIREBASE_CLIENT_EMAIL;
    delete process.env.FIREBASE_PRIVATE_KEY;
    resetIngestPushCooldownForTests();
  });

  afterEach(() => {
    for (const [key, value] of Object.entries(envBackup)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    resetIngestPushCooldownForTests();
  });

  it('normalizes FCM data values to strings', () => {
    assert.deepEqual(
      normalizeFcmData({ postId: 42, type: 'news', skip: null, keep: undefined }),
      { postId: '42', type: 'news' },
    );
  });

  it('reports push health when firebase is not configured', () => {
    const health = getPushHealth();
    assert.equal(health.configured, false);
    assert.equal(health.enabled, false);
    assert.equal(health.notifyOnIngest, true);
    assert.equal(health.minInserted, 5);
    assert.deepEqual(health.ingestSources, ['news']);
  });

  it('skips ingest notify when firebase is not configured', async () => {
    process.env.PUSH_MIN_INSERTED = '1';
    const result = await notifyFeedIngestion({ inserted: 10, source: 'news' });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'disabled');
  });

  it('skips youtube ingest source by default policy', async () => {
    process.env.FIREBASE_PROJECT_ID = 'newsapp-test';
    process.env.FIREBASE_CLIENT_EMAIL = 'firebase@test.iam.gserviceaccount.com';
    process.env.FIREBASE_PRIVATE_KEY = 'test-private-key';
    process.env.PUSH_MIN_INSERTED = '1';
    const result = await notifyFeedIngestion({ inserted: 10, source: 'youtube' });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'source_excluded');
  });
});
