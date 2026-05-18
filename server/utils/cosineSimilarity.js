/**
 * Cosine similarity for normalized embedding vectors.
 */

function dot(a, b) {
  let s = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i += 1) s += a[i] * b[i];
  return s;
}

function norm(a) {
  return Math.sqrt(dot(a, a));
}

/** Vectors should be L2-normalized; returns value in [-1, 1]. */
function cosineSimilarity(a, b) {
  if (!a?.length || !b?.length) return 0;
  const na = norm(a);
  const nb = norm(b);
  if (na === 0 || nb === 0) return 0;
  return dot(a, b) / (na * nb);
}

/** Best label from precomputed prototype vectors. */
function classifyByPrototypes(embedding, prototypeMap) {
  let bestLabel = null;
  let bestScore = -1;
  const scores = {};

  for (const [label, vectors] of Object.entries(prototypeMap)) {
    let maxForLabel = -1;
    for (const vec of vectors) {
      const sim = cosineSimilarity(embedding, vec);
      if (sim > maxForLabel) maxForLabel = sim;
    }
    scores[label] = maxForLabel;
    if (maxForLabel > bestScore) {
      bestScore = maxForLabel;
      bestLabel = label;
    }
  }

  return { label: bestLabel, score: bestScore, scores };
}

module.exports = {
  cosineSimilarity,
  classifyByPrototypes,
};
