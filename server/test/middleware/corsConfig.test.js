const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseAllowedOrigins,
  buildCorsOptions,
} = require('../../middleware/corsConfig');

describe('corsConfig', () => {
  const saved = {};

  beforeEach(() => {
    saved.NODE_ENV = process.env.NODE_ENV;
    saved.ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS;
  });

  afterEach(() => {
    if (saved.NODE_ENV === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = saved.NODE_ENV;
    if (saved.ALLOWED_ORIGINS === undefined) delete process.env.ALLOWED_ORIGINS;
    else process.env.ALLOWED_ORIGINS = saved.ALLOWED_ORIGINS;
  });

  it('parses || and comma separated origins with schemes added', () => {
    process.env.ALLOWED_ORIGINS = 'localhost:3000||https://app.example.com';
    const list = parseAllowedOrigins();
    assert.ok(list.includes('http://localhost:3000'));
    assert.ok(list.includes('https://localhost:3000'));
    assert.ok(list.includes('https://app.example.com'));
  });

  it('returns null allowlist in development when unset', () => {
    delete process.env.ALLOWED_ORIGINS;
    process.env.NODE_ENV = 'development';
    assert.equal(parseAllowedOrigins(), null);
    const opts = buildCorsOptions();
    assert.equal(opts.origin, true);
  });

  it('returns empty allowlist in production when unset', () => {
    delete process.env.ALLOWED_ORIGINS;
    process.env.NODE_ENV = 'production';
    assert.deepEqual(parseAllowedOrigins(), []);
    assert.equal(buildCorsOptions().origin, false);
  });
});
