const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  chatRequestTimeoutMs,
  translateRequestTimeoutMs,
} = require('../../middleware/requestTimeout');

describe('requestTimeout helpers', () => {
  it('chatRequestTimeoutMs defaults to 60s', () => {
    const saved = process.env.CHAT_REQUEST_TIMEOUT_MS;
    delete process.env.CHAT_REQUEST_TIMEOUT_MS;
    assert.equal(chatRequestTimeoutMs(), 60000);
    if (saved === undefined) delete process.env.CHAT_REQUEST_TIMEOUT_MS;
    else process.env.CHAT_REQUEST_TIMEOUT_MS = saved;
  });

  it('chatRequestTimeoutMs clamps to configured value', () => {
    const saved = process.env.CHAT_REQUEST_TIMEOUT_MS;
    process.env.CHAT_REQUEST_TIMEOUT_MS = '45000';
    assert.equal(chatRequestTimeoutMs(), 45000);
    if (saved === undefined) delete process.env.CHAT_REQUEST_TIMEOUT_MS;
    else process.env.CHAT_REQUEST_TIMEOUT_MS = saved;
  });

  it('translateRequestTimeoutMs defaults to 90s', () => {
    const saved = process.env.TRANSLATE_REQUEST_TIMEOUT_MS;
    delete process.env.TRANSLATE_REQUEST_TIMEOUT_MS;
    assert.equal(translateRequestTimeoutMs(), 90000);
    if (saved === undefined) delete process.env.TRANSLATE_REQUEST_TIMEOUT_MS;
    else process.env.TRANSLATE_REQUEST_TIMEOUT_MS = saved;
  });
});
