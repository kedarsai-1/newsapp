const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  clientIp,
  isReadHeavyRequest,
  maxForRequest,
  _pruneStaleBuckets,
} = require('../../middleware/apiRateLimit');

describe('apiRateLimit', () => {
  it('clientIp uses leftmost X-Forwarded-For address', () => {
    const req = {
      ip: '10.0.0.1',
      headers: { 'x-forwarded-for': '203.0.113.5, 70.41.3.18, 150.172.238.178' },
    };
    assert.equal(clientIp(req), '203.0.113.5');
  });

  it('clientIp falls back to req.ip when header missing', () => {
    assert.equal(clientIp({ ip: '127.0.0.1', headers: {} }), '127.0.0.1');
  });

  it('clientIp trims spaces around forwarded IP', () => {
    const req = { headers: { 'x-forwarded-for': '  198.51.100.22 , 10.0.0.1' } };
    assert.equal(clientIp(req), '198.51.100.22');
  });

  it('treats feed GET as read-heavy', () => {
    const req = { method: 'GET', path: '/api/news/feed', headers: {} };
    assert.equal(isReadHeavyRequest(req), true);
  });

  it('treats auth POST as write bucket', () => {
    const req = { method: 'POST', path: '/api/auth/login', headers: {} };
    assert.equal(isReadHeavyRequest(req), false);
  });

  it('read-heavy limit is higher than write limit', () => {
    const readReq = { method: 'GET', path: '/api/news/feed', headers: {} };
    const writeReq = { method: 'POST', path: '/api/auth/login', headers: {} };
    assert.ok(maxForRequest(readReq) >= maxForRequest(writeReq));
  });

  it('_pruneStaleBuckets runs without error', () => {
    assert.doesNotThrow(() => _pruneStaleBuckets());
  });
});
