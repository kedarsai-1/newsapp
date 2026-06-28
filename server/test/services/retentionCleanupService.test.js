const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { retentionDaysFromEnv } = require('../../services/retentionCleanupService');

describe('retentionCleanupService', () => {
  it('retentionDaysFromEnv defaults to 18 (15–20 day window)', () => {
    const prev = process.env.RETENTION_DAYS;
    delete process.env.RETENTION_DAYS;
    delete process.env.CLOUDINARY_RETENTION_DAYS;
    assert.equal(retentionDaysFromEnv(), 18);
    process.env.RETENTION_DAYS = '15';
    assert.equal(retentionDaysFromEnv(), 15);
    process.env.RETENTION_DAYS = '20';
    assert.equal(retentionDaysFromEnv(), 20);
    if (prev == null) delete process.env.RETENTION_DAYS;
    else process.env.RETENTION_DAYS = prev;
  });
});
