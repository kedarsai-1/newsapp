const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { sendOtpHandler, verifyLoginOtp } = require('../../controllers/otpController');
const { prisma } = require('../../config/prisma');
const otpService = require('../../utils/otpService');

describe('otpController verifyLoginOtp', () => {
  it('rejects admin accounts even with a valid OTP', async () => {
    const originalVerify = otpService.verifyOtp;
    otpService.verifyOtp = async () => ({ valid: true });
    const originalFindFirst = prisma.user.findFirst;
    prisma.user.findFirst = async () => ({
      id: 'admin-1',
      role: 'admin',
      isActive: true,
      email: 'admin@newsapp.com',
    });

    const req = { body: { target: 'admin@newsapp.com', code: '123456' } };
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
      await verifyLoginOtp(req, res);
      assert.equal(res.statusCode, 403);
      assert.match(res.body.message, /password login/i);
    } finally {
      otpService.verifyOtp = originalVerify;
      prisma.user.findFirst = originalFindFirst;
    }
  });
});

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
