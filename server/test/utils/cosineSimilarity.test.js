const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  cosineSimilarity,
  classifyByPrototypes,
} = require('../../utils/cosineSimilarity');

describe('cosineSimilarity', () => {
  it('returns 1 for identical vectors', () => {
    const v = [1, 0, 0];
    assert.ok(Math.abs(cosineSimilarity(v, v) - 1) < 1e-6);
  });

  it('returns 0 for empty or zero vectors', () => {
    assert.equal(cosineSimilarity([], [1, 2]), 0);
    assert.equal(cosineSimilarity([0, 0], [1, 1]), 0);
  });

  it('classifyByPrototypes picks highest-scoring label', () => {
    const embedding = [1, 0];
    const prototypes = {
      politics: [[1, 0]],
      sports: [[0, 1]],
    };
    const result = classifyByPrototypes(embedding, prototypes);
    assert.equal(result.label, 'politics');
    assert.ok(result.score > 0.9);
  });
});
