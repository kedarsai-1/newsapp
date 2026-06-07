const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  extractKeywords,
  detectCategorySlug,
  buildSystemPrompt,
  formatArticle,
} = require('../../services/newsChatService');

describe('newsChatService', () => {
  it('extracts keywords and drops stop words', () => {
    const words = extractKeywords('What is the latest cricket news today?');
    assert.ok(words.includes('cricket'));
    assert.ok(!words.includes('what'));
    assert.ok(!words.includes('latest'));
    assert.ok(!words.includes('news'));
  });

  it('detects topic categories from natural questions', () => {
    assert.equal(detectCategorySlug('IPL match score update'), 'sports');
    assert.equal(detectCategorySlug('Modi election speech'), 'politics');
    assert.equal(detectCategorySlug('Apple new iPhone launch'), 'technology');
    assert.equal(detectCategorySlug('Will it rain tomorrow?'), 'weather');
    assert.equal(detectCategorySlug('random hello'), null);
  });

  it('uses Dailyhunt-style multilingual system prompts', () => {
    assert.match(buildSystemPrompt('en'), /Dailyhunt-style/i);
    assert.match(buildSystemPrompt('hi'), /Hindi only/);
    assert.match(buildSystemPrompt('te'), /Telugu only/);
  });

  it('formats article context with body snippet', () => {
    const text = formatArticle({
      title: 'Test headline',
      summary: 'Short summary',
      body: 'Long body '.repeat(50),
      sourcePublishedAt: new Date('2026-06-07'),
      category: { name: 'Politics', slug: 'politics' },
    }, 0);
    assert.match(text, /Test headline/);
    assert.match(text, /Politics/);
    assert.match(text, /Details:/);
  });
});
