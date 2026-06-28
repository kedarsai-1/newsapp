/**
 * Local Ollama (Contabo VPS) or Hugging Face inference for summaries & translation.
 *
 * Set AI_PROVIDER=ollama on VPS with Ollama on 127.0.0.1:11434.
 * Falls back to Hugging Face when AI_PROVIDER=huggingface (default).
 */

const FEED_LANG_LABELS = {
  en: 'English',
  hi: 'Hindi',
  te: 'Telugu',
};

const { decodeHtmlEntities } = require('../utils/decodeHtmlEntities');
const { chatRequestTimeoutMs } = require('../middleware/requestTimeout');
const {
  clipSummaryForStorage,
  SUMMARY_STORAGE_MAX_CHARS,
} = require('../utils/summaryText');

let chatQueuePending = 0;
let ollamaChatInFlight = 0;
let ollamaChatQueue = Promise.resolve();
let activeIngestAbortController = null;

function abortActiveIngestInference() {
  try {
    activeIngestAbortController?.abort();
  } catch {
    /* ignore */
  }
  activeIngestAbortController = null;
}

function trackIngestAbortController(ac) {
  if (!ollamaInstancesSeparate()) {
    activeIngestAbortController = ac;
  }
}

function releaseIngestAbortController(ac) {
  if (activeIngestAbortController === ac) {
    activeIngestAbortController = null;
  }
}

/** Global Ollama scheduler — one inference at a time; chat jumps ahead of ingest. */
const OLLAMA_PRIORITY_CHAT = 2;
const OLLAMA_PRIORITY_INGEST = 1;
const OLLAMA_PRIORITY_WARM = 0;
let ollamaJobQueue = [];
let ollamaJobRunning = false;
let ollamaJobSeq = 0;

/** Back off ingest Ollama after consecutive timeouts/aborts (shared instance overload). */
let ollamaIngestCircuit = { failures: 0, openUntil: 0 };
let ollamaCircuitHfBackupLoggedUntil = 0;

function ollamaCircuitFailureThreshold() {
  return Math.max(2, Number(process.env.OLLAMA_CIRCUIT_FAILURES || 3));
}

function ollamaCircuitCooldownMs() {
  return Math.max(60_000, Number(process.env.OLLAMA_CIRCUIT_COOLDOWN_MS || 300_000));
}

function isOllamaIngestCircuitOpen() {
  return Date.now() < ollamaIngestCircuit.openUntil;
}

function isOllamaUnderLoad() {
  return ollamaJobRunning || ollamaJobQueue.length > 1;
}

function recordOllamaIngestFailure(err) {
  if (isChatPriorityError(err)) return;
  // Chat preempts ingest via abortActiveIngestInference — not an Ollama outage.
  if (isOllamaAbortError(err) && hasPendingChatWork()) return;
  ollamaIngestCircuit.failures += 1;
  if (ollamaIngestCircuit.failures >= ollamaCircuitFailureThreshold()) {
    ollamaIngestCircuit.openUntil = Date.now() + ollamaCircuitCooldownMs();
    ollamaIngestCircuit.failures = 0;
    console.warn(
      `[ai] Ollama ingest circuit open for ${Math.round(ollamaCircuitCooldownMs() / 1000)}s `
        + '— extractive summaries until cooldown',
    );
  }
}

function recordOllamaIngestSuccess() {
  ollamaIngestCircuit.failures = 0;
  ollamaIngestCircuit.openUntil = 0;
}

function drainOllamaJobQueue() {
  if (ollamaJobRunning || !ollamaJobQueue.length) return;
  ollamaJobRunning = true;
  const job = ollamaJobQueue.shift();
  Promise.resolve()
    .then(() => job.fn())
    .then((result) => job.resolve(result))
    .catch((err) => job.reject(err))
    .finally(() => {
      ollamaJobRunning = false;
      drainOllamaJobQueue();
    });
}

function enqueueOllamaJob(fn, priority = OLLAMA_PRIORITY_INGEST) {
  return new Promise((resolve, reject) => {
    if (priority >= OLLAMA_PRIORITY_CHAT && !ollamaInstancesSeparate()) {
      abortActiveIngestInference();
    }
    const seq = ollamaJobSeq++;
    ollamaJobQueue.push({ fn, priority, seq, resolve, reject });
    ollamaJobQueue.sort((a, b) => b.priority - a.priority || a.seq - b.seq);
    drainOllamaJobQueue();
  });
}

function hasPendingChatWork() {
  if (chatQueuePending > 0 || ollamaChatInFlight > 0) return true;
  return ollamaJobQueue.some((j) => j.priority >= OLLAMA_PRIORITY_CHAT);
}

function shouldYieldIngestToChat() {
  if (process.env.OLLAMA_INGEST_YIELD_TO_CHAT === 'false') return false;
  if (ollamaInstancesSeparate()) return false;
  return hasPendingChatWork();
}

function isChatPriorityError(err) {
  return String(err?.message || '').includes('OLLAMA_CHAT_PRIORITY');
}

function ollamaInstancesSeparate() {
  return ollamaChatBaseUrl() !== ollamaBaseUrl();
}

function withOllamaIngestionQueue(fn) {
  if (ollamaInstancesSeparate()) {
    return Promise.resolve().then(fn);
  }
  if (shouldYieldIngestToChat()) {
    return Promise.reject(new Error('OLLAMA_CHAT_PRIORITY'));
  }
  return enqueueOllamaJob(fn, OLLAMA_PRIORITY_INGEST);
}

function withOllamaChatQueue(fn) {
  if (ollamaInstancesSeparate()) {
    const run = ollamaChatQueue.then(fn, fn);
    ollamaChatQueue = run.catch(() => {});
    return run;
  }
  return enqueueOllamaJob(fn, OLLAMA_PRIORITY_CHAT);
}

/** Reserve FIFO position for queue-aware HTTP timeout (call at chat handler entry). */
function acquireChatQueueSlot() {
  const queueIndex = chatQueuePending;
  chatQueuePending += 1;
  if (!ollamaInstancesSeparate()) {
    abortActiveIngestInference();
  }
  return {
    queueIndex,
    release() {
      chatQueuePending = Math.max(0, chatQueuePending - 1);
    },
  };
}

function getChatQueuePending() {
  return chatQueuePending;
}

/** Wall-clock budget: context build + (queueIndex + 1) Ollama chat slots + buffer. */
function chatHandlerTimeoutMs(queueIndex = 0) {
  const contextMs = Math.max(
    3000,
    Number(process.env.CHAT_CONTEXT_TIMEOUT_MS || 8000),
  );
  const ollamaMs = ollamaChatTimeoutMs();
  const bufferMs = Math.max(1000, Number(process.env.CHAT_HANDLER_TIMEOUT_BUFFER_MS || 5000));
  const depth = Math.max(0, Number(queueIndex) || 0);
  const total = contextMs + (depth + 1) * ollamaMs + bufferMs;
  const floor = contextMs + ollamaMs + Math.max(15000, bufferMs);
  const cap = Math.min(
    600_000,
    Math.max(
      chatRequestTimeoutMs(),
      Number(process.env.CHAT_HANDLER_TIMEOUT_MS_CAP || 360_000),
    ),
  );
  return Math.min(cap, Math.max(total, floor));
}

function getAiProvider() {
  return String(process.env.AI_PROVIDER || 'huggingface').toLowerCase().trim();
}

function isOllamaProvider() {
  return getAiProvider() === 'ollama';
}

function ollamaBaseUrl() {
  return String(process.env.OLLAMA_BASE_URL || 'http://127.0.0.1:11434').replace(/\/$/, '');
}

/** Optional separate Ollama instance for chat (falls back to ingest URL). */
function ollamaChatBaseUrl() {
  const chatUrl = String(process.env.OLLAMA_CHAT_BASE_URL || '').trim();
  if (chatUrl) return chatUrl.replace(/\/$/, '');
  return ollamaBaseUrl();
}

/** Default model if no per-language override. */
function ollamaModel() {
  return String(process.env.OLLAMA_MODEL || 'llama3.1:8b').trim();
}

/**
 * Best model per language on 11 GB VPS (see docs/OLLAMA_SETUP.md).
 * hi/te: Sarvam-1 (Indic-trained). en: Llama 3.1 8B.
 */
function ollamaModelForLanguage(lang) {
  const l = String(lang || 'en').toLowerCase();
  const indicDefault = String(
    process.env.OLLAMA_MODEL_INDIC || 'mashriram/sarvam-1',
  ).trim();

  if (l === 'hi') {
    return String(process.env.OLLAMA_MODEL_HI || indicDefault).trim();
  }
  if (l === 'te') {
    return String(process.env.OLLAMA_MODEL_TE || indicDefault).trim();
  }
  if (l === 'en') {
    return String(process.env.OLLAMA_MODEL_EN || ollamaModel()).trim();
  }
  return ollamaModel();
}

/** Fast model for user chat — separate from ingest summarization models. */
function ollamaChatModelDefault() {
  return String(process.env.OLLAMA_MODEL_CHAT || 'gemma2:2b').trim();
}

function ollamaModelForChat(lang) {
  const l = String(lang || 'en').toLowerCase();
  const chatDefault = ollamaChatModelDefault();

  if (l === 'hi') {
    return String(process.env.OLLAMA_MODEL_CHAT_HI || chatDefault).trim();
  }
  if (l === 'te') {
    return String(process.env.OLLAMA_MODEL_CHAT_TE || chatDefault).trim();
  }
  if (l === 'en') {
    return String(process.env.OLLAMA_MODEL_CHAT_EN || chatDefault).trim();
  }
  return chatDefault;
}

function getConfiguredOllamaModels() {
  return [...new Set([
    ollamaModelForLanguage('en'),
    ollamaModelForLanguage('hi'),
    ollamaModelForLanguage('te'),
  ])];
}

function getConfiguredOllamaChatModels() {
  return [...new Set([
    ollamaModelForChat('en'),
    ollamaModelForChat('hi'),
    ollamaModelForChat('te'),
  ])];
}

function useOllamaChatApi() {
  return process.env.OLLAMA_USE_CHAT_API !== 'false';
}

function ollamaTimeoutMs() {
  return Math.min(
    600000,
    Math.max(10000, Number(process.env.OLLAMA_TIMEOUT_MS || 180000)),
  );
}

function ollamaChatTimeoutMs() {
  return Math.min(
    chatRequestTimeoutMs() - 2000,
    Math.max(10000, Number(process.env.OLLAMA_CHAT_TIMEOUT_MS || 58000)),
  );
}

function ollamaChatMaxTokens() {
  return Math.max(64, Number(process.env.OLLAMA_CHAT_MAX_TOKENS || 120));
}

/** Indic chat answers need more tokens (longer glyphs per sentence). */
function ollamaChatMaxTokensForLang(lang) {
  const l = String(lang || 'en').toLowerCase();
  const base = ollamaChatMaxTokens();
  if (l === 'hi' || l === 'te') {
    const indic = Number(process.env.OLLAMA_CHAT_MAX_TOKENS_INDIC || 220);
    return Math.max(base, Math.min(400, indic));
  }
  return base;
}

function ollamaKeepAlive() {
  return String(process.env.OLLAMA_KEEP_ALIVE || '15m').trim();
}

/** True when AI summaries are allowed (Ollama local or HF token). */
function isAiSummaryEnabled() {
  if (process.env.RSS_SKIP_AI_SUMMARY === 'true') return false;
  if (process.env.RSS_INDIC_AI_SUMMARY === 'false' && process.env.RSS_AI_SUMMARY === 'false') {
    return false;
  }
  if (isOllamaProvider()) return true;
  return Boolean(String(process.env.HF_TOKEN || '').trim());
}

function cleanModelOutput(text) {
  let t = decodeHtmlEntities(
    String(text || '')
      .replace(/^summary:\s*/i, '')
      .replace(/^translation:\s*/i, '')
      .replace(/^["']|["']$/g, ''),
  );

  const metaCut = t.search(/\((?:Note|Translation|Output|The term)/i);
  if (metaCut > 20) t = t.slice(0, metaCut).trim();

  return t.replace(/\s+/g, ' ').trim();
}

/** Reject wrong script (e.g. Chinese in English, garbled Telugu). */
function validateLanguageOutput(text, targetLang, options = {}) {
  const t = cleanModelOutput(text);
  if (!t || t.length < 12) return '';

  const lang = String(targetLang || 'en').toLowerCase();
  const latin = (t.match(/[A-Za-z]/g) || []).length;
  const devanagari = (t.match(/[\u0900-\u097F]/g) || []).length;
  const telugu = (t.match(/[\u0C00-\u0C7F]/g) || []).length;
  const cjk = (t.match(/[\u4E00-\u9FFF]/g) || []).length;
  const total = latin + devanagari + telugu + cjk;
  if (total < 8) return '';

  if (cjk > 0) return '';

  if (lang === 'en' && latin / total < 0.55) return '';
  if (lang === 'hi' && devanagari / total < 0.35 && latin / total < 0.35) return '';
  if (lang === 'te' && telugu / total < 0.35) return '';

  if (options.forSummary) {
    return clipSummaryForStorage(t);
  }

  const maxChars = Math.max(
    320,
    Number(options.maxChars || process.env.CHAT_ANSWER_MAX_CHARS || 320),
  );
  if (t.length <= maxChars) return t;
  const slice = t.slice(0, maxChars);
  const lastSentEnd = Math.max(
    slice.lastIndexOf('. '),
    slice.lastIndexOf('। '),
    slice.lastIndexOf('? '),
    slice.lastIndexOf('! '),
  );
  if (lastSentEnd > 80) return slice.slice(0, lastSentEnd + 1).trim();
  return `${slice.slice(0, 317).trim()}…`;
}

function ollamaSummaryMaxTokens() {
  return Math.min(
    1024,
    Math.max(256, Number(process.env.OLLAMA_SUMMARY_MAX_TOKENS || 512)),
  );
}

function summarySystemPrompt(targetLang) {
  const lang = FEED_LANG_LABELS[String(targetLang || 'en').toLowerCase()] || 'English';
  return (
    `You write news summaries for an Indian news app. `
    + `Reply with ONE complete summary in ${lang} only. Write 4–6 full sentences (up to ${SUMMARY_STORAGE_MAX_CHARS} characters). `
    + `Cover who, what, when, where, and why. End with a complete sentence — never stop mid-word or mid-thought. `
    + `Factual, neutral. No bullets, no quotes, no Chinese, no meta notes, no "(Note:" text.`
  );
}

function summaryUserPrompt(text) {
  const maxInput = Math.min(
    6000,
    Math.max(1200, Number(process.env.RSS_SUMMARY_INPUT_MAX_CHARS || 3000)),
  );
  return `Article:\n${String(text || '').trim().slice(0, maxInput)}\n\nSummary:`;
}

function translationSystemPrompt(targetLang) {
  const lang = FEED_LANG_LABELS[String(targetLang || 'en').toLowerCase()] || 'English';
  return `Translate to ${lang} only. Output translation only. No notes or Chinese.`;
}

function translationUserPrompt(text) {
  return String(text || '').trim().slice(0, 1200);
}

async function ollamaChatRequest({
  baseUrl,
  model,
  system,
  user,
  lang = 'en',
  timeoutMs = null,
  forChat = false,
  numPredict = null,
}) {
  const url = `${baseUrl}/api/chat`;
  const ac = new AbortController();
  if (!forChat) trackIngestAbortController(ac);
  const timer = setTimeout(() => ac.abort(), timeoutMs ?? ollamaTimeoutMs());
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
        stream: false,
        keep_alive: ollamaKeepAlive(),
        options: {
          temperature: Number(
            forChat
              ? (process.env.OLLAMA_CHAT_TEMPERATURE || process.env.OLLAMA_TEMPERATURE || 0.2)
              : (process.env.OLLAMA_TEMPERATURE || 0.1),
          ),
          num_predict: numPredict ?? (forChat
            ? ollamaChatMaxTokensForLang(lang)
            : Number(process.env.OLLAMA_MAX_TOKENS || 150)),
          top_p: 0.9,
        },
      }),
      signal: ac.signal,
    });
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Ollama ${response.status}${body ? `: ${body.slice(0, 200)}` : ''}`);
    }
    const data = await response.json();
    return cleanModelOutput(data?.message?.content || '');
  } finally {
    clearTimeout(timer);
    releaseIngestAbortController(ac);
  }
}

async function ollamaChatForIngest(system, user, lang = 'en', timeoutMs = null) {
  return ollamaChatRequest({
    baseUrl: ollamaBaseUrl(),
    model: ollamaModelForLanguage(lang),
    system,
    user,
    lang,
    timeoutMs,
    forChat: false,
  });
}

async function ollamaChatForUser(system, user, lang = 'en', timeoutMs = null) {
  return ollamaChatRequest({
    baseUrl: ollamaChatBaseUrl(),
    model: ollamaModelForChat(lang),
    system,
    user,
    lang,
    timeoutMs,
    forChat: true,
  });
}

function ollamaSummaryTimeoutMs() {
  return Math.min(
    180_000,
    Math.max(30_000, Number(process.env.OLLAMA_SUMMARY_TIMEOUT_MS || 90_000)),
  );
}

async function ollamaComplete(system, user, lang = 'en', timeoutMs = null, numPredict = null) {
  const model = ollamaModelForLanguage(lang);
  if (useOllamaChatApi()) {
    return ollamaChatRequest({
      baseUrl: ollamaBaseUrl(),
      model,
      system,
      user,
      lang,
      timeoutMs: timeoutMs ?? ollamaTimeoutMs(),
      forChat: false,
      numPredict,
    });
  }
  const url = `${ollamaBaseUrl()}/api/generate`;
  const ac = new AbortController();
  trackIngestAbortController(ac);
  const timer = setTimeout(() => ac.abort(), timeoutMs ?? ollamaTimeoutMs());
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt: `${system}\n\n${user}`,
        stream: false,
        options: {
          temperature: Number(process.env.OLLAMA_TEMPERATURE || 0.1),
          num_predict: numPredict ?? Number(process.env.OLLAMA_MAX_TOKENS || 150),
        },
      }),
      signal: ac.signal,
    });
    if (!response.ok) throw new Error(`Ollama ${response.status}`);
    const data = await response.json();
    return cleanModelOutput(data?.response || '');
  } finally {
    clearTimeout(timer);
    releaseIngestAbortController(ac);
  }
}

async function ollamaCompleteQueued(system, user, lang = 'en', timeoutMs = null, numPredict = null) {
  if (!ollamaInstancesSeparate() && shouldYieldIngestToChat()) {
    throw new Error('OLLAMA_CHAT_PRIORITY');
  }
  if (ollamaInstancesSeparate()) {
    return ollamaComplete(system, user, lang, timeoutMs, numPredict);
  }
  return enqueueOllamaJob(
    () => ollamaComplete(system, user, lang, timeoutMs, numPredict),
    OLLAMA_PRIORITY_INGEST,
  );
}

async function ollamaCompleteForSummary(system, user, lang = 'en') {
  if (isOllamaIngestCircuitOpen()) {
    throw new Error('OLLAMA_CIRCUIT_OPEN');
  }
  try {
    const result = await ollamaCompleteQueued(
      system,
      user,
      lang,
      ollamaSummaryTimeoutMs(),
      ollamaSummaryMaxTokens(),
    );
    recordOllamaIngestSuccess();
    return result;
  } catch (e) {
    if (isOllamaAbortError(e) || isChatPriorityError(e)) {
      recordOllamaIngestFailure(e);
    }
    throw e;
  }
}

function parseHfSummarizationJson(result) {
  if (result == null) return '';
  if (typeof result === 'string') return result.trim();
  if (Array.isArray(result)) {
    const first = result[0];
    if (first?.summary_text != null) return String(first.summary_text).trim();
  }
  if (typeof result === 'object' && result.summary_text != null) {
    return String(result.summary_text).trim();
  }
  return '';
}

function parseHfTranslationJson(result) {
  if (result == null) return '';
  if (typeof result === 'string') return result.trim();
  if (Array.isArray(result)) {
    const first = result[0];
    if (first?.translation_text != null) return String(first.translation_text).trim();
  }
  if (typeof result === 'object' && result.translation_text != null) {
    return String(result.translation_text).trim();
  }
  return '';
}

async function hfFetch(modelPath, inputs, extraBody = {}) {
  const token = String(process.env.HF_TOKEN || '').trim();
  if (!token) throw new Error('HF_TOKEN is missing');
  const hfMs = Math.min(
    120000,
    Math.max(5000, Number(process.env.HF_SUMMARY_TIMEOUT_MS || 22000)),
  );
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), hfMs);
  try {
    const response = await fetch(
      `https://router.huggingface.co/hf-inference/models/${modelPath}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        method: 'POST',
        body: JSON.stringify({ inputs, ...extraBody }),
        signal: ac.signal,
      },
    );
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`HF ${response.status}${body ? ` - ${body.slice(0, 200)}` : ''}`);
    }
    return response.json();
  } finally {
    clearTimeout(timer);
  }
}

async function summarizeWithHf(text) {
  const input = String(text || '').slice(0, 2000).trim();
  const result = await hfFetch('sshleifer/distilbart-cnn-12-6', input);
  return parseHfSummarizationJson(result);
}

async function translateToEnglishWithHf(text) {
  const input = String(text || '').slice(0, 800);
  const result = await hfFetch('Helsinki-NLP/opus-mt-mul-en', input);
  return parseHfTranslationJson(result) || input;
}

async function translateEnglishToHindiWithHf(text) {
  const result = await hfFetch('Helsinki-NLP/opus-mt-en-hi', String(text || '').slice(0, 600));
  return parseHfTranslationJson(result);
}

async function translateEnglishToTeluguWithHf(text) {
  const input = `>>tel<< ${String(text || '').slice(0, 512)}`;
  const result = await hfFetch('Helsinki-NLP/opus-mt-en-dra', input);
  return parseHfTranslationJson(result);
}

/**
 * Summarize in target feed language (en / hi / te).
 * Ollama: one multilingual call. HF: English distilbart (+ translate for hi/te).
 */
async function summarize(text, targetLang = 'en') {
  const input = String(text || '').trim();
  if (!input) return '';
  const lang = String(targetLang || 'en').toLowerCase();

  // For English: Ollama primary (if enabled), HF backup
  if (lang === 'en') {
    const circuitOpen = isOllamaProvider() && isOllamaIngestCircuitOpen();
    if (isOllamaProvider() && !circuitOpen) {
      try {
        const model = ollamaModelForLanguage('en');
        const raw = await ollamaCompleteForSummary(
          summarySystemPrompt('en'),
          summaryUserPrompt(input),
          'en',
        );
        const out = validateLanguageOutput(raw, 'en', { forSummary: true });
        if (out) return out;
      } catch (e) {
        if (isChatPriorityError(e)) return '';
        const hasHf = Boolean(String(process.env.HF_TOKEN || '').trim());
        if (isOllamaAbortError(e)) {
          if (hasHf) {
            console.warn(`[ai] Ollama summarization aborted: ${e.message}. Trying HF backup...`);
          }
        } else if (e.message !== 'OLLAMA_CIRCUIT_OPEN') {
          console.error(`[ai] English Ollama summarization failed: ${e.message}`);
        }
      }
    } else if (circuitOpen) {
      const now = Date.now();
      if (now >= ollamaCircuitHfBackupLoggedUntil) {
        ollamaCircuitHfBackupLoggedUntil = ollamaIngestCircuit.openUntil;
        const hasHf = Boolean(String(process.env.HF_TOKEN || '').trim());
        console.warn(
          hasHf
            ? '[ai] Ollama ingest circuit open — trying HF backup for English summary'
            : '[ai] Ollama ingest circuit open — extractive summaries until cooldown',
        );
      }
    }
    const hasHfToken = Boolean(String(process.env.HF_TOKEN || '').trim());
    if (hasHfToken) {
      try {
        const out = await summarizeWithHf(input);
        if (out) return out;
      } catch (hfErr) {
        console.error(`[ai] English HF fallback summarization failed: ${hfErr.message}`);
      }
    }
  } else {
    // For Telugu/Hindi: Ollama primary, HF backup
    if (isOllamaProvider()) {
      try {
        const model = ollamaModelForLanguage(lang);
        const raw = await ollamaCompleteForSummary(
          summarySystemPrompt(lang),
          summaryUserPrompt(input),
          lang,
        );
        const out = validateLanguageOutput(raw, lang, { forSummary: true });
        if (out) return out;
        console.warn(
          `[ai] Ollama summary rejected (lang=${lang}, model=${model}). Trying HF backup...`,
        );
      } catch (e) {
        if (isChatPriorityError(e) || e.message === 'OLLAMA_CIRCUIT_OPEN') return '';
        const hasHf = Boolean(String(process.env.HF_TOKEN || '').trim());
        if (isOllamaAbortError(e)) {
          if (hasHf) {
            console.warn(`Ollama summarization aborted: ${e.message || e}. Trying HF backup...`);
          }
        } else {
          console.error(`Ollama summarization failed: ${e.message || e}${hasHf ? '. Trying HF backup...' : ''}`);
        }
      }
    }
    // Fallback/Backup to Hugging Face
    const hasHfToken = Boolean(String(process.env.HF_TOKEN || '').trim());
    if (hasHfToken) {
      try {
        const englishText = await translateToEnglish(input);
        const latinCount = (englishText.match(/[A-Za-z]/g) || []).length;
        const isEnglish = englishText && latinCount > (englishText.length * 0.5);

        if (isEnglish && englishText !== input) {
          let summaryEn = await summarizeWithHf(englishText);
          if (summaryEn) {
            const prevProvider = process.env.AI_PROVIDER;
            process.env.AI_PROVIDER = 'huggingface';
            try {
              const tr = await translateToFeedLanguage(summaryEn, lang);
              if (tr?.trim()) return tr.trim();
            } finally {
              if (prevProvider !== undefined) process.env.AI_PROVIDER = prevProvider;
              else delete process.env.AI_PROVIDER;
            }
          }
        } else {
          console.warn(
            `[ai] Hugging Face backup skipped for ${lang}: translation to English failed/skipped.`,
          );
        }
      } catch (hfErr) {
        console.error(`[ai] Hugging Face backup failed: ${hfErr.message}`);
      }
    }
  }

  return '';
}

async function translateToEnglish(text) {
  const raw = String(text || '').trim();
  if (!raw) return '';

  // 1. Try Ollama first if it is the selected provider
  if (isOllamaProvider()) {
    try {
      const out = validateLanguageOutput(
        await ollamaCompleteQueued(
          translationSystemPrompt('en'),
          translationUserPrompt(raw),
          'en',
        ),
        'en',
      );
      if (out) return out;
    } catch (e) {
      console.error(`[ai] Ollama translateToEnglish failed: ${e.message}`);
    }
  }

  // 2. Fallback to Hugging Face
  const hasHfToken = Boolean(String(process.env.HF_TOKEN || '').trim());
  if (hasHfToken) {
    try {
      return await translateToEnglishWithHf(raw);
    } catch (hfErr) {
      console.error(`[ai] English HF translation fallback failed: ${hfErr.message}`);
    }
  }

  return raw;
}

async function translateToFeedLanguage(text, targetLang) {
  const raw = String(text || '').trim();
  const target = String(targetLang || '').toLowerCase();
  if (!raw || !['en', 'hi', 'te'].includes(target)) return raw;

  if (target === 'en') {
    return translateToEnglish(raw);
  }

  if (isOllamaProvider()) {
    try {
      const out = validateLanguageOutput(
        await ollamaCompleteQueued(
          translationSystemPrompt(target),
          translationUserPrompt(raw),
          target,
        ),
        target,
      );
      if (out) return out;
    } catch (e) {
      console.error(`[ai] Ollama translation failed for ${target}: ${e.message}`);
    }
  }

  // Fallback to Hugging Face if HF_TOKEN is configured
  const hasHfToken = Boolean(String(process.env.HF_TOKEN || '').trim());
  if (hasHfToken) {
    try {
      if (target === 'hi') {
        const out = await translateEnglishToHindiWithHf(raw);
        if (out) return out;
      }
      if (target === 'te') {
        const out = await translateEnglishToTeluguWithHf(raw);
        if (out) return out;
      }
    } catch (hfErr) {
      console.error(`[ai] Hugging Face translation fallback failed: ${hfErr.message}`);
    }
  }

  return raw;
}

async function areTitlesSameStory(titleA, titleB, lang = 'en') {
  if (!isOllamaProvider() || process.env.OLLAMA_YOUTUBE_DEDUPE === 'false') {
    return false;
  }
  const a = String(titleA || '').trim().slice(0, 220);
  const b = String(titleB || '').trim().slice(0, 220);
  if (!a || !b) return false;
  if (a.toLowerCase() === b.toLowerCase()) return true;

  const system = (
    'You detect duplicate news videos. Reply with exactly YES if both titles describe '
    + 'the same news story or event, otherwise NO. One word only.'
  );
  const user = `Title A: ${a}\nTitle B: ${b}\nSame story?`;

  try {
    const out = await withOllamaIngestionQueue(() => ollamaChatForIngest(system, user, lang));
    return /^yes\b/i.test(String(out || '').trim());
  } catch {
    return false;
  }
}

function modelIsInstalled(name, installed) {
  return installed.some((n) => n === name || n.startsWith(`${name}:`));
}

function ollamaTagsTimeoutMs() {
  return Math.min(
    30_000,
    Math.max(5000, Number(process.env.OLLAMA_TAGS_TIMEOUT_MS || 15_000)),
  );
}

function ollamaTagsRetries() {
  return Math.max(0, Math.min(3, Number(process.env.OLLAMA_TAGS_RETRIES || 2)));
}

function isTransientOllamaError(err) {
  const msg = String(err?.message || err || '');
  return err?.name === 'TimeoutError'
    || err?.name === 'AbortError'
    || /timeout|timed out|ECONNREFUSED|ECONNRESET|fetch failed|network/i.test(msg);
}

async function fetchOllamaInstalledModels(baseUrl) {
  const timeoutMs = ollamaTagsTimeoutMs();
  const retries = ollamaTagsRetries();
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const res = await fetch(`${baseUrl}/api/tags`, {
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return (data?.models || []).map((m) => m.name);
    } catch (e) {
      lastErr = e;
      if (attempt < retries) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise((resolve) => {
          setTimeout(resolve, 400 * (attempt + 1));
        });
      }
    }
  }
  throw lastErr;
}

function buildOllamaPingResult({ installed, required, modelsByLang, baseUrl }) {
  const missing = required.filter((name) => !modelIsInstalled(name, installed));
  return {
    ok: missing.length === 0,
    baseUrl,
    models: installed,
    required,
    missing,
    modelsByLang,
  };
}

async function pingOllamaAt(baseUrl, required, modelsByLang) {
  try {
    const installed = await fetchOllamaInstalledModels(baseUrl);
    return buildOllamaPingResult({ installed, required, modelsByLang, baseUrl });
  } catch (e) {
    if (isTransientOllamaError(e)) {
      return {
        ok: false,
        transient: true,
        baseUrl,
        error: e.message,
        required,
        missing: [],
        modelsByLang,
      };
    }
    return {
      ok: false,
      baseUrl,
      error: e.message,
      required,
      missing: required,
      modelsByLang,
    };
  }
}

async function pingOllama() {
  if (!isOllamaProvider()) return { ok: false, skipped: true };

  const ingestRequired = getConfiguredOllamaModels();
  const ingestModelsByLang = {
    en: ollamaModelForLanguage('en'),
    hi: ollamaModelForLanguage('hi'),
    te: ollamaModelForLanguage('te'),
  };
  const ingestPing = await pingOllamaAt(ollamaBaseUrl(), ingestRequired, ingestModelsByLang);

  const chatBase = ollamaChatBaseUrl();
  const chatRequired = getConfiguredOllamaChatModels();
  const chatModelsByLang = {
    en: ollamaModelForChat('en'),
    hi: ollamaModelForChat('hi'),
    te: ollamaModelForChat('te'),
  };

  let chatPing;
  if (chatBase === ollamaBaseUrl()) {
    const chatMissing = chatRequired.filter(
      (name) => !modelIsInstalled(name, ingestPing.models || []),
    );
    chatPing = {
      ok: chatMissing.length === 0,
      baseUrl: chatBase,
      models: ingestPing.models,
      required: chatRequired,
      missing: chatMissing,
      modelsByLang: chatModelsByLang,
    };
  } else {
    chatPing = await pingOllamaAt(chatBase, chatRequired, chatModelsByLang);
  }

  const allMissing = [...new Set([
    ...(ingestPing.missing || []),
    ...(chatPing.missing || []),
  ])];

  return {
    ok: ingestPing.ok === true && chatPing.ok === true,
    models: ingestPing.models || [],
    required: [...new Set([...ingestRequired, ...chatRequired])],
    missing: allMissing,
    modelsByLang: ingestModelsByLang,
    chatModelsByLang,
    ingest: ingestPing,
    chat: chatPing,
    error: ingestPing.error || chatPing.error || null,
  };
}

const OLLAMA_CHAT_STATUS_OK_TTL_MS = Math.max(
  10_000,
  Number(process.env.OLLAMA_HEALTH_TTL_MS || 60_000),
);
const OLLAMA_CHAT_STATUS_FAIL_TTL_MS = Math.max(
  3000,
  Number(process.env.OLLAMA_HEALTH_FAIL_TTL_MS || 5000),
);

function ollamaChatStatusCacheTtl(payload) {
  if (payload?.ok) return OLLAMA_CHAT_STATUS_OK_TTL_MS;
  return OLLAMA_CHAT_STATUS_FAIL_TTL_MS;
}

let ollamaChatStatusCache = { at: 0, ttl: 0, payload: null };

async function getOllamaChatStatus(forceRefresh = false) {
  if (!isOllamaProvider()) return { ok: false, skipped: true };

  const now = Date.now();
  if (
    !forceRefresh
    && ollamaChatStatusCache.payload
    && now - ollamaChatStatusCache.at < ollamaChatStatusCache.ttl
  ) {
    return ollamaChatStatusCache.payload;
  }

  const chatBase = ollamaChatBaseUrl();
  const chatRequired = getConfiguredOllamaChatModels();
  const chatModelsByLang = {
    en: ollamaModelForChat('en'),
    hi: ollamaModelForChat('hi'),
    te: ollamaModelForChat('te'),
  };

  let payload;
  if (chatBase === ollamaBaseUrl()) {
    const full = await pingOllama();
    payload = {
      ok: full.chat?.ok === true,
      baseUrl: chatBase,
      required: chatRequired,
      missing: full.chat?.missing || [],
      modelsByLang: chatModelsByLang,
      error: full.chat?.error || full.error || null,
    };
  } else {
    const chatPing = await pingOllamaAt(chatBase, chatRequired, chatModelsByLang);
    payload = {
      ok: chatPing.ok === true,
      baseUrl: chatBase,
      required: chatRequired,
      missing: chatPing.missing || [],
      modelsByLang: chatModelsByLang,
      error: chatPing.error || null,
    };
  }

  ollamaChatStatusCache = { at: now, ttl: ollamaChatStatusCacheTtl(payload), payload };
  return payload;
}

/** True when chat models are confirmed absent (not a busy/timeout ping). */
function ollamaChatModelsConfirmedMissing(status) {
  return status?.ok !== true
    && !status?.transient
    && Array.isArray(status?.missing)
    && status.missing.length > 0;
}

function isOllamaAbortError(err) {
  const msg = String(err?.message || err || '');
  return err?.name === 'AbortError' || /aborted|timeout|timed out/i.test(msg);
}

async function chatWithOllama(systemPrompt, userPrompt, lang = 'en') {
  if (!isOllamaProvider()) {
    throw new Error('Ollama provider is not enabled in environment');
  }
  return withOllamaChatQueue(async () => {
    ollamaChatInFlight += 1;
    try {
      const raw = await ollamaChatForUser(
        systemPrompt,
        userPrompt,
        lang,
        ollamaChatTimeoutMs(),
      );
      const validated = validateLanguageOutput(raw, lang, {
        maxChars: Number(process.env.CHAT_ANSWER_MAX_CHARS || 700),
      });
      if (validated) return validated;
      const l = String(lang || 'en').toLowerCase();
      if (l === 'hi' || l === 'te') return '';
      return String(raw || '').trim();
    } finally {
      ollamaChatInFlight = Math.max(0, ollamaChatInFlight - 1);
    }
  });
}

function warmOllamaLanguages() {
  const raw = process.env.OLLAMA_WARM_LANGS || 'en,hi,te';
  return [...new Set(
    raw.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
  )];
}

async function warmOllamaChatModels() {
  if (!isOllamaProvider()) return { ok: false, skipped: true };
  if (process.env.OLLAMA_WARM_ON_START === 'false') return { ok: false, skipped: true };
  if (isOllamaIngestCircuitOpen() || isOllamaUnderLoad()) {
    return { ok: false, skipped: true, reason: 'ollama_busy' };
  }

  const warmTimeoutMs = Math.min(
    45000,
    Math.max(5000, Number(process.env.OLLAMA_WARM_TIMEOUT_MS || 25000)),
  );
  const langs = warmOllamaLanguages();
  const seenModels = new Set();
  const results = {};

  for (const lang of langs) {
    const model = ollamaModelForChat(lang);
    if (seenModels.has(model)) continue;
    seenModels.add(model);
    try {
      // eslint-disable-next-line no-await-in-loop
      await enqueueOllamaJob(
        () => ollamaChatForUser(
          'Reply with exactly: OK',
          'warmup',
          lang,
          warmTimeoutMs,
        ),
        OLLAMA_PRIORITY_WARM,
      );
      results[model] = 'ok';
    } catch (err) {
      results[model] = err?.message || String(err);
      if (!isOllamaAbortError(err)) {
        console.warn(`[ai] Ollama warm failed (${model}):`, results[model]);
      }
    }
  }

  const ok = Object.values(results).length > 0
    && Object.values(results).every((v) => v === 'ok');
  if (ok) {
    console.log(`[ai] Ollama chat warmed: ${Object.keys(results).join(', ')}`);
  }
  return { ok, results };
}

let warmIntervalTimer = null;

function scheduleOllamaWarmInterval() {
  if (!isOllamaProvider()) return;
  if (process.env.OLLAMA_WARM_INTERVAL_MS === '0') return;
  const intervalMs = Math.max(
    300_000,
    Number(process.env.OLLAMA_WARM_INTERVAL_MS || 900_000),
  );
  if (warmIntervalTimer) clearInterval(warmIntervalTimer);
  warmIntervalTimer = setInterval(() => {
    warmOllamaChatModels().catch((err) => {
      console.warn('[ai] Ollama periodic warm failed:', err?.message || err);
    });
  }, intervalMs);
  if (typeof warmIntervalTimer.unref === 'function') warmIntervalTimer.unref();
}

module.exports = {
  getAiProvider,
  isOllamaProvider,
  isAiSummaryEnabled,
  summarize,
  translateToEnglish,
  translateToFeedLanguage,
  pingOllama,
  getOllamaChatStatus,
  ollamaChatModelsConfirmedMissing,
  ollamaChatBaseUrl,
  ollamaInstancesSeparate,
  ollamaModelForLanguage,
  ollamaModelForChat,
  getConfiguredOllamaModels,
  getConfiguredOllamaChatModels,
  validateLanguageOutput,
  cleanModelOutput,
  areTitlesSameStory,
  chatWithOllama,
  warmOllamaChatModels,
  scheduleOllamaWarmInterval,
  ollamaChatTimeoutMs,
  ollamaChatMaxTokens,
  ollamaSummaryTimeoutMs,
  isOllamaAbortError,
  isOllamaIngestCircuitOpen,
  hasPendingChatWork,
  shouldYieldIngestToChat,
  withOllamaChatQueue,
  withOllamaIngestionQueue,
  acquireChatQueueSlot,
  getChatQueuePending,
  chatHandlerTimeoutMs,
};
