const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');

const { generateToken, authorize } = require('../../middleware/authMiddleware');

describe('authMiddleware', () => {
  let origJwtSecret;
  let origJwtExpiresIn;

  before(() => {
    origJwtSecret = process.env.JWT_SECRET;
    origJwtExpiresIn = process.env.JWT_EXPIRES_IN;
    process.env.JWT_SECRET = 'unit-test-secret';
    process.env.JWT_EXPIRES_IN = '1h';
  });

  after(() => {
    if (origJwtSecret === undefined) {
      delete process.env.JWT_SECRET;
    } else {
      process.env.JWT_SECRET = origJwtSecret;
    }
    if (origJwtExpiresIn === undefined) {
      delete process.env.JWT_EXPIRES_IN;
    } else {
      process.env.JWT_EXPIRES_IN = origJwtExpiresIn;
    }
  });

  it('generateToken creates a verifiable JWT', () => {
    const token = generateToken('user-123');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    assert.equal(decoded.id, 'user-123');
  });

  it('authorize calls next when role matches', () => {
    const middleware = authorize('reporter', 'admin');
    let nextCalled = false;
    const req = { user: { role: 'reporter' } };
    const res = {
      statusCode: null,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(payload) {
        this.body = payload;
        return this;
      },
    };

    middleware(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
    assert.equal(res.statusCode, null);
  });

  it('authorize returns 403 when role does not match', () => {
    const middleware = authorize('admin');
    let nextCalled = false;
    const req = { user: { role: 'user' } };
    const res = {
      statusCode: null,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(payload) {
        this.body = payload;
        return this;
      },
    };

    middleware(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, false);
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.success, false);
  });
});
