const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const otpRateLimit = require('../../middleware/otpRateLimit');

describe('otpRateLimit', () => {
  it('returns 429 after exceeding per-target limit', () => {
    const req = {
      body: { target: 'user@example.com' },
      headers: {},
      ip: '203.0.113.10',
    };
    let statusCode = 200;
    const res = {
      setHeader() {},
      status(code) {
        statusCode = code;
        return this;
      },
      json() {
        return this;
      },
    };

    for (let i = 0; i < 3; i += 1) {
      let nextCalled = false;
      otpRateLimit(req, res, () => {
        nextCalled = true;
      });
      assert.equal(statusCode, 200, `attempt ${i + 1}`);
      assert.equal(nextCalled, true);
    }

    let blocked = false;
    otpRateLimit(req, res, () => {
      blocked = true;
    });
    assert.equal(statusCode, 429);
    assert.equal(blocked, false);
  });
});
