const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { validateFcmToken, MIN_FCM_TOKEN_LEN } = require('../../utils/fcmValidation');

describe('fcmValidation', () => {
  it('rejects missing token', () => {
    assert.equal(validateFcmToken(undefined).ok, false);
    assert.equal(validateFcmToken('   ').ok, false);
  });

  it('rejects too-short token', () => {
    assert.equal(validateFcmToken('abc').ok, false);
  });

  it('accepts realistic-length token', () => {
    const token = 'a'.repeat(MIN_FCM_TOKEN_LEN);
    const result = validateFcmToken(token);
    assert.equal(result.ok, true);
    assert.equal(result.value, token);
  });
});
