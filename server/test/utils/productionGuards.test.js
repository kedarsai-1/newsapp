const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  assertProductionSecrets,
  isWeakAdminPassword,
  resolveAdminSeedPassword,
} = require('../../utils/productionGuards');

describe('productionGuards', () => {
  it('rejects weak JWT secret in production', () => {
    const prev = { ...process.env };
    const originalExit = process.exit;
    try {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'change_me_in_production';
      process.exit = (code) => {
        throw new Error(`exit:${code}`);
      };
      assert.throws(() => assertProductionSecrets(), /exit:1/);
    } finally {
      process.exit = originalExit;
      process.env = prev;
    }
  });

  it('allows strong JWT secret in production', () => {
    const prev = { ...process.env };
    try {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'a'.repeat(48);
      assert.doesNotThrow(() => assertProductionSecrets());
    } finally {
      process.env = prev;
    }
  });

  it('requires ADMIN_SEED_PASSWORD in production when resolving', () => {
    const prev = { ...process.env };
    const originalExit = process.exit;
    try {
      process.env.NODE_ENV = 'production';
      delete process.env.ADMIN_SEED_PASSWORD;
      process.exit = (code) => {
        throw new Error(`exit:${code}`);
      };
      assert.throws(() => resolveAdminSeedPassword(), /exit:1/);
    } finally {
      process.exit = originalExit;
      process.env = prev;
    }
  });

  it('flags default admin password as weak', () => {
    assert.equal(isWeakAdminPassword('Admin@123'), true);
    assert.equal(isWeakAdminPassword('Str0ng!UniqueSeedPass'), false);
  });
});
