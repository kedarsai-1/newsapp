const { summarizeForRssIngest } = require('./rssService');
const {
  isAiSummaryEnabled,
  isOllamaProvider,
  shouldYieldIngestToChat,
  isOllamaIngestCircuitOpen,
} = require('./aiProvider');

function summaryMinBudgetMs() {
  const ollama = isOllamaProvider();
  const envKey = ollama ? 'OLLAMA_SUMMARY_MIN_BUDGET_MS' : 'HF_SUMMARY_MIN_BUDGET_MS';
  const fallback = ollama ? 55_000 : 30_000;
  return Math.max(20_000, Number(process.env[envKey] || fallback));
}

function summaryMaxRetries() {
  return Math.max(0, Math.min(2, Number(process.env.INGEST_SUMMARY_MAX_RETRIES || 1)));
}

function isSummaryBudgetAvailable(budget) {
  if (process.env.RSS_SKIP_AI_SUMMARY === 'true') return false;
  if (!isAiSummaryEnabled()) return false;
  if (!budget?.limitMs) return true;
  return budget.remainingMs() >= summaryMinBudgetMs();
}

function isSummaryBudgetTight(budget) {
  if (!budget?.limitMs) return false;
  return budget.remainingMs() < summaryMinBudgetMs();
}

/**
 * Production ingest summarization for en / hi / te feed languages.
 * Retries once on transient Ollama failures; callers apply RSS extractive fallback when this returns empty.
 */
async function summarizeForIngest({
  text,
  originalLang,
  feedLang,
  budget = null,
  stats = null,
}) {
  const src = String(text || '').trim();
  const fl = String(feedLang || 'en').toLowerCase();
  if (!src) return { summary: '', source: 'empty' };

  if (process.env.RSS_SKIP_AI_SUMMARY === 'true') {
    stats && (stats.summarySkippedConfig += 1);
    return { summary: '', source: 'disabled' };
  }

  if (!isAiSummaryEnabled()) {
    stats && (stats.summarySkippedAiOff += 1);
    return { summary: '', source: 'ai_off' };
  }

  if (!isSummaryBudgetAvailable(budget)) {
    stats && (stats.summarySkippedBudget += 1);
    return { summary: '', source: 'budget' };
  }

  if (shouldYieldIngestToChat()) {
    stats && (stats.summarySkippedChatPriority += 1);
  } else if (isOllamaProvider() && isOllamaIngestCircuitOpen()) {
    stats && (stats.summarySkippedCircuit += 1);
  }

  // Chat priority skips all AI; circuit open still allows HF backup inside aiSummarize.
  const skipAi = shouldYieldIngestToChat();

  const retries = summaryMaxRetries();
  let lastError = null;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const summary = await summarizeForRssIngest(src, originalLang, fl, { skipAi });
      const trimmed = String(summary || '').trim();
      if (trimmed) {
        stats && (stats.summaryAiOk += 1);
        if (attempt > 0) stats && (stats.summaryAiRetryOk += 1);
        const source = skipAi
          ? 'chat_priority_extractive'
          : (attempt > 0 ? 'ai_retry' : 'ai');
        return { summary: trimmed, source };
      }
    } catch (err) {
      lastError = err;
      if (String(err?.message || '').includes('OLLAMA_CHAT_PRIORITY')) {
        stats && (stats.summarySkippedChatPriority += 1);
        skipAi = true;
        continue;
      }
      if (String(err?.message || '').includes('OLLAMA_CIRCUIT_OPEN')) {
        stats && (stats.summarySkippedCircuit += 1);
        skipAi = true;
        continue;
      }
      if (attempt < retries) {
        stats && (stats.summaryAiRetries += 1);
        // eslint-disable-next-line no-await-in-loop
        await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
      }
    }
  }

  if (lastError) {
    stats && (stats.summaryAiErrors += 1);
    console.warn(
      `[ingest-summary] AI failed (${fl}, lang=${originalLang}): ${lastError.message || lastError}`,
    );
  } else {
    stats && (stats.summaryAiEmpty += 1);
  }

  return { summary: '', source: 'ai_failed' };
}

function createSummaryStats() {
  return {
    summaryAiOk: 0,
    summaryAiRetryOk: 0,
    summaryAiRetries: 0,
    summaryAiErrors: 0,
    summaryAiEmpty: 0,
    summarySkippedBudget: 0,
    summarySkippedConfig: 0,
    summarySkippedAiOff: 0,
    summarySkippedChatPriority: 0,
    summarySkippedCircuit: 0,
    summaryExtractiveFallback: 0,
  };
}

module.exports = {
  summarizeForIngest,
  isSummaryBudgetAvailable,
  isSummaryBudgetTight,
  summaryMinBudgetMs,
  createSummaryStats,
};
