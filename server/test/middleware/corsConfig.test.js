const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseAllowedOrigins,
  buildCorsOptions,
  isLocalDevOrigin,
} = require('../../middleware/corsConfig');

describe('corsConfig', () => {
  const saved = {};

  beforeEach(() => {
    saved.NODE_ENV = process.env.NODE_ENV;
    saved.ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS;
    saved.CORS_ALLOW_LOCALHOST = process.env.CORS_ALLOW_LOCALHOST;
  });

  afterEach(() => {
    if (saved.NODE_ENV === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = saved.NODE_ENV;
    if (saved.ALLOWED_ORIGINS === undefined) delete process.env.ALLOWED_ORIGINS;
    else process.env.ALLOWED_ORIGINS = saved.ALLOWED_ORIGINS;
    if (saved.CORS_ALLOW_LOCALHOST === undefined) delete process.env.CORS_ALLOW_LOCALHOST;
    else process.env.CORS_ALLOW_LOCALHOST = saved.CORS_ALLOW_LOCALHOST;
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

  it('blocks localhost in production unless CORS_ALLOW_LOCALHOST=true', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.CORS_ALLOW_LOCALHOST;
    assert.equal(isLocalDevOrigin('http://localhost:51712'), false);
    process.env.CORS_ALLOW_LOCALHOST = 'true';
    assert.equal(isLocalDevOrigin('http://localhost:51712'), true);
  });

  it('allows localhost in non-production by default', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.CORS_ALLOW_LOCALHOST;
    assert.equal(isLocalDevOrigin('http://127.0.0.1:8080'), true);
  });

  it('rejects blocked origins without throwing (callback null, false)', () => {
    process.env.ALLOWED_ORIGINS = 'https://app.example.com';
    process.env.NODE_ENV = 'production';
    const { origin } = buildCorsOptions();
    assert.equal(typeof origin, 'function');

    return new Promise((resolve, reject) => {
      origin('https://evil.example.com', (err, allowed) => {
        try {
          assert.equal(err, null);
          assert.equal(allowed, false);
          resolve();
        } catch (e) {
          reject(e);
        }
      });
    });
  });
});
