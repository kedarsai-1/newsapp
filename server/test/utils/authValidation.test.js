const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  validateRegisterPayload,
  validateOtpRegisterPayload,
  validatePassword,
  validatePhone,
  resolveRegistrationRole,
} = require('../../utils/authValidation');

describe('authValidation', () => {
  it('rejects short passwords', () => {
    assert.equal(validatePassword('abc1').ok, false);
  });

  it('accepts letter and number with min 8 chars', () => {
    assert.equal(validatePassword('secret12').ok, true);
  });

  it('maps admin to user', () => {
    assert.equal(resolveRegistrationRole('admin'), 'user');
  });

  it('allows reporter role', () => {
    assert.equal(resolveRegistrationRole('reporter'), 'reporter');
  });

  it('requires email for reporter role', () => {
    const result = validateRegisterPayload({
      name: 'Test User',
      email: '',
      password: 'secret12',
      phone: null,
      role: 'reporter',
    });
    assert.equal(result.ok, false);
  });

  it('accepts valid reporter registration', () => {
    const result = validateRegisterPayload({
      name: 'Test User',
      email: 'reporter@test.com',
      password: 'secret12',
      phone: null,
      role: 'reporter',
    });
    assert.equal(result.ok, true);
    assert.equal(result.data.role, 'reporter');
  });

  it('rejects reporter role via OTP', () => {
    const result = validateOtpRegisterPayload({
      name: 'Rep',
      email: 'r@test.com',
      password: 'secret12',
      role: 'reporter',
    });
    assert.equal(result.ok, false);
    assert.match(result.message, /email and password/i);
  });

  it('rejects phone with too few digits', () => {
    assert.equal(validatePhone('(123) 45').ok, false);
  });

  it('accepts phone with 10 digits', () => {
    assert.equal(validatePhone('9876543210').ok, true);
  });

  it('accepts user OTP registration', () => {
    const result = validateOtpRegisterPayload({
      name: 'User',
      email: 'u@test.com',
      password: 'secret12',
      role: 'user',
    });
    assert.equal(result.ok, true);
    assert.equal(result.data.role, 'user');
  });
});
