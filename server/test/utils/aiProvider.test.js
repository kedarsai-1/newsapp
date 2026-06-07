const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isAiSummaryEnabled,
  isOllamaProvider,
  getAiProvider,
  validateLanguageOutput,
  ollamaModelForLanguage,
  getConfiguredOllamaModels,
} = require('../../services/aiProvider');

describe('aiProvider', () => {
  it('isOllamaProvider when AI_PROVIDER=ollama', () => {
    const prev = process.env.AI_PROVIDER;
    process.env.AI_PROVIDER = 'ollama';
    assert.equal(isOllamaProvider(), true);
    assert.equal(getAiProvider(), 'ollama');
    if (prev === undefined) delete process.env.AI_PROVIDER;
    else process.env.AI_PROVIDER = prev;
  });

  it('isAiSummaryEnabled with ollama without HF_TOKEN', () => {
    const prevProvider = process.env.AI_PROVIDER;
    const prevSkip = process.env.RSS_SKIP_AI_SUMMARY;
    const prevToken = process.env.HF_TOKEN;

    process.env.AI_PROVIDER = 'ollama';
    delete process.env.HF_TOKEN;
    process.env.RSS_SKIP_AI_SUMMARY = 'false';
    assert.equal(isAiSummaryEnabled(), true);

    process.env.RSS_SKIP_AI_SUMMARY = 'true';
    assert.equal(isAiSummaryEnabled(), false);

    if (prevProvider === undefined) delete process.env.AI_PROVIDER;
    else process.env.AI_PROVIDER = prevProvider;
    if (prevSkip === undefined) delete process.env.RSS_SKIP_AI_SUMMARY;
    else process.env.RSS_SKIP_AI_SUMMARY = prevSkip;
    if (prevToken === undefined) delete process.env.HF_TOKEN;
    else process.env.HF_TOKEN = prevToken;
  });

  it('validateLanguageOutput rejects Chinese in English summary', () => {
    const bad = 'India policy on digital rupee 数字货币 (Note: kept in Chinese)';
    assert.equal(validateLanguageOutput(bad, 'en'), '');
    const good = 'India announced a new digital rupee policy for retail payments.';
    assert.ok(validateLanguageOutput(good, 'en').length > 20);
  });

  it('validateLanguageOutput requires Telugu script for te', () => {
    const bad = 'Some English only summary without Telugu letters';
    assert.equal(validateLanguageOutput(bad, 'te'), '');
  });

  it('ollamaModelForLanguage picks Indic model for hi/te', () => {
    const keys = [
      'OLLAMA_MODEL',
      'OLLAMA_MODEL_EN',
      'OLLAMA_MODEL_INDIC',
      'OLLAMA_MODEL_HI',
      'OLLAMA_MODEL_TE',
    ];
    const saved = Object.fromEntries(keys.map((k) => [k, process.env[k]]));
    process.env.OLLAMA_MODEL = 'llama3.1:8b';
    process.env.OLLAMA_MODEL_INDIC = 'mashriram/sarvam-1';
    delete process.env.OLLAMA_MODEL_HI;
    delete process.env.OLLAMA_MODEL_TE;

    assert.equal(ollamaModelForLanguage('en'), 'llama3.1:8b');
    assert.equal(ollamaModelForLanguage('hi'), 'mashriram/sarvam-1');
    assert.equal(ollamaModelForLanguage('te'), 'mashriram/sarvam-1');
    assert.deepEqual(getConfiguredOllamaModels().sort(), [
      'llama3.1:8b',
      'mashriram/sarvam-1',
    ]);

    for (const k of keys) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  });

  it('ollamaChatTimeoutMs defaults below ingestion timeout', () => {
    const {
      ollamaChatTimeoutMs,
      isOllamaAbortError,
    } = require('../../services/aiProvider');
    const savedChat = process.env.OLLAMA_CHAT_TIMEOUT_MS;
    const savedIngest = process.env.OLLAMA_TIMEOUT_MS;
    delete process.env.OLLAMA_CHAT_TIMEOUT_MS;
    process.env.OLLAMA_TIMEOUT_MS = '180000';
    assert.ok(ollamaChatTimeoutMs() < 180000);
    assert.equal(isOllamaAbortError({ name: 'AbortError' }), true);
    assert.equal(isOllamaAbortError(new Error('fetch aborted')), true);
    if (savedChat === undefined) delete process.env.OLLAMA_CHAT_TIMEOUT_MS;
    else process.env.OLLAMA_CHAT_TIMEOUT_MS = savedChat;
    if (savedIngest === undefined) delete process.env.OLLAMA_TIMEOUT_MS;
    else process.env.OLLAMA_TIMEOUT_MS = savedIngest;
  });
});
