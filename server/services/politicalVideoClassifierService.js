/**
 * Multilingual political video classifier — Xenova/paraphrase-multilingual-MiniLM-L12-v2.
 * Preloads once, caches label prototype embeddings, batches uncertain items only.
 */
const path = require('path');
const fs = require('fs');
const { isRailwayHost } = require('../utils/isRailway');
const {
  LABEL_PROTOTYPES,
  POLITICAL_LABELS,
  NON_POLITICAL_LABELS,
} = require('../config/politicalVideoConfig');
const { classifyByPrototypes } = require('../utils/cosineSimilarity');
const { normalizeText } = require('../utils/politicalKeywordFilter');

const MODEL_ID =
  process.env.POLITICAL_ML_MODEL || 'Xenova/paraphrase-multilingual-MiniLM-L12-v2';

const CACHE_FILE =
  process.env.POLITICAL_EMBEDDING_CACHE
  || path.join(__dirname, '../.cache/political-label-embeddings.json');

let embedder = null;
let prototypeVectors = null;
let preloadPromise = null;
let transformersModule = null;

function isMlEnabled() {
  if (process.env.POLITICAL_ML_ENABLED === 'false') return false;
  if (process.env.POLITICAL_ML_ENABLED === 'true') return true;
  return !isRailwayHost();
}

async function loadTransformers() {
  if (!transformersModule) {
    transformersModule = await import('@xenova/transformers');
  }
  return transformersModule;
}

function configureEnv(tf) {
  const { env } = tf;
  env.cacheDir = process.env.TRANSFORMERS_CACHE_DIR
    || path.join(__dirname, '../.cache/transformers');
  env.backends.onnx.wasm.numThreads = Math.max(
    1,
    Math.min(2, Number(process.env.TRANSFORMERS_THREADS || (isRailwayHost() ? 1 : 2))),
  );
}

function tensorToVector(output) {
  if (!output) return [];
  if (Array.isArray(output?.data)) return [...output.data];
  if (output?.data) return Array.from(output.data);
  return [];
}

async function getEmbedder() {
  if (embedder) return embedder;
  const tf = await loadTransformers();
  configureEnv(tf);
  embedder = await tf.pipeline('feature-extraction', MODEL_ID, {
    quantized: true,
  });
  return embedder;
}

async function embedBatch(texts, batchSize = 8) {
  const pipe = await getEmbedder();
  const vectors = [];
  const clean = texts.map((t) => String(t || '').slice(0, 512));

  for (let i = 0; i < clean.length; i += batchSize) {
    const chunk = clean.slice(i, i + batchSize);
    // eslint-disable-next-line no-await-in-loop
    const out = await pipe(chunk, { pooling: 'mean', normalize: true });
    if (Array.isArray(out)) {
      for (const item of out) vectors.push(tensorToVector(item));
    } else {
      vectors.push(tensorToVector(out));
    }
  }
  return vectors;
}

async function buildPrototypeVectors() {
  if (prototypeVectors) return prototypeVectors;

  if (fs.existsSync(CACHE_FILE)) {
    try {
      const cached = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
      if (cached?.model === MODEL_ID && cached?.prototypes) {
        prototypeVectors = cached.prototypes;
        return prototypeVectors;
      }
    } catch {
      /* rebuild */
    }
  }

  await getEmbedder();
  const prototypes = {};

  for (const [label, sentences] of Object.entries(LABEL_PROTOTYPES)) {
    // eslint-disable-next-line no-await-in-loop
    const vecs = await embedBatch(sentences, 4);
    prototypes[label] = vecs.filter((v) => v.length > 0);
  }

  prototypeVectors = prototypes;
  try {
    fs.mkdirSync(path.dirname(CACHE_FILE), { recursive: true });
    fs.writeFileSync(
      CACHE_FILE,
      JSON.stringify({ model: MODEL_ID, prototypes }),
    );
  } catch (e) {
    console.warn('[political-ml] could not write embedding cache:', e.message);
  }

  return prototypeVectors;
}

/**
 * Preload model + prototype embeddings (call on server boot or first cron).
 */
function preloadPoliticalClassifier() {
  if (!isMlEnabled()) {
    return Promise.resolve();
  }
  if (!preloadPromise) {
    preloadPromise = buildPrototypeVectors()
      .then(() => {
        console.log('[political-ml] model and label prototypes ready');
      })
      .catch((e) => {
        preloadPromise = null;
        throw e;
      });
  }
  return preloadPromise;
}

/**
 * Classify uncertain videos in batches (CPU-friendly).
 * @param {Array<{title, description}>} items
 */
async function classifyVideosBatch(items) {
  if (!items.length) return [];
  if (!isMlEnabled()) {
    return items.map((item) => ({
      ...item,
      category: null,
      confidence: 0,
      method: 'ml',
      accepted: false,
      scores: {},
    }));
  }

  const prototypes = await buildPrototypeVectors();
  const texts = items.map((v) => normalizeText(v.title, v.description));
  const vectors = await embedBatch(texts, Number(process.env.POLITICAL_ML_BATCH || 8));

  const minPolitical =
    Number(process.env.POLITICAL_ML_MIN_SCORE || 0.42);
  const minMargin =
    Number(process.env.POLITICAL_ML_MIN_MARGIN || 0.04);

  return items.map((item, idx) => {
    const embedding = vectors[idx] || [];
    const { label, score, scores } = classifyByPrototypes(embedding, prototypes);

    const bestPolitical = POLITICAL_LABELS.reduce(
      (best, l) => (scores[l] > (scores[best] ?? -1) ? l : best),
      POLITICAL_LABELS[0],
    );
    const bestNonPolitical = NON_POLITICAL_LABELS.reduce(
      (best, l) => (scores[l] > (scores[best] ?? -1) ? l : best),
      NON_POLITICAL_LABELS[0],
    );
    const polScore = scores[bestPolitical] ?? 0;
    const negScore = scores[bestNonPolitical] ?? 0;
    const accepted =
      POLITICAL_LABELS.includes(label)
      && polScore >= minPolitical
      && polScore >= negScore + minMargin;

    return {
      ...item,
      category: accepted ? label : null,
      confidence: polScore,
      method: 'ml',
      accepted,
      scores,
    };
  });
}

module.exports = {
  preloadPoliticalClassifier,
  classifyVideosBatch,
  buildPrototypeVectors,
  isMlEnabled,
};
