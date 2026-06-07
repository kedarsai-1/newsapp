const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { sendOtpHandler } = require('../../controllers/otpController');
const { prisma } = require('../../config/prisma');

describe('otpController sendOtpHandler', () => {
  it('login with unknown email returns generic 200 without revealing absence', async () => {
    const originalFindFirst = prisma.user.findFirst;
    prisma.user.findFirst = async () => null;

    const req = {
      body: { target: 'unknown@example.com', purpose: 'login' },
    };
    const res = {
      statusCode: 200,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };

    try {
      await sendOtpHandler(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(res.body.success, true);
      assert.match(res.body.message, /If an account exists/i);
    } finally {
      prisma.user.findFirst = originalFindFirst;
    }
  });
});
