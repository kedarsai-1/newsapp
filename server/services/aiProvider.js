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

let ollamaIngestionQueue = Promise.resolve();
let ollamaChatQueue = Promise.resolve();

function withOllamaIngestionQueue(fn) {
  const run = ollamaIngestionQueue.then(fn, fn);
  ollamaIngestionQueue = run.catch(() => {});
  return run;
}

function withOllamaChatQueue(fn) {
  const run = ollamaChatQueue.then(fn, fn);
  ollamaChatQueue = run.catch(() => {});
  return run;
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

function getConfiguredOllamaModels() {
  return [...new Set([
    ollamaModelForLanguage('en'),
    ollamaModelForLanguage('hi'),
    ollamaModelForLanguage('te'),
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
    120000,
    Math.max(10000, Number(process.env.OLLAMA_CHAT_TIMEOUT_MS || 45000)),
  );
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
function validateLanguageOutput(text, targetLang) {
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

  if (t.length <= 320) return t;
  // Truncate at last sentence boundary within 320 chars
  const slice = t.slice(0, 320);
  const lastSentEnd = Math.max(
    slice.lastIndexOf('. '),
    slice.lastIndexOf('। '),
    slice.lastIndexOf('? '),
    slice.lastIndexOf('! '),
  );
  if (lastSentEnd > 80) return slice.slice(0, lastSentEnd + 1).trim();
  return `${slice.slice(0, 317).trim()}…`;
}

function summarySystemPrompt(targetLang) {
  const lang = FEED_LANG_LABELS[String(targetLang || 'en').toLowerCase()] || 'English';
  return (
    `You write news summaries for an Indian news app. `
    + `Reply with ONE short summary in ${lang} only. Max 280 characters. `
    + `Factual, neutral. No bullets, no quotes, no Chinese, no meta notes, no "(Note:" text.`
  );
}

function summaryUserPrompt(text) {
  return `Article:\n${String(text || '').trim().slice(0, 1800)}\n\nSummary:`;
}

function translationSystemPrompt(targetLang) {
  const lang = FEED_LANG_LABELS[String(targetLang || 'en').toLowerCase()] || 'English';
  return `Translate to ${lang} only. Output translation only. No notes or Chinese.`;
}

function translationUserPrompt(text) {
  return String(text || '').trim().slice(0, 1200);
}

async function ollamaChat(system, user, lang = 'en', timeoutMs = null) {
  const url = `${ollamaBaseUrl()}/api/chat`;
  const model = ollamaModelForLanguage(lang);
  const ac = new AbortController();
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
        options: {
          temperature: Number(process.env.OLLAMA_TEMPERATURE || 0.1),
          num_predict: Number(process.env.OLLAMA_MAX_TOKENS || 150),
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
  }
}

function ollamaSummaryTimeoutMs() {
  return Math.min(
    180_000,
    Math.max(30_000, Number(process.env.OLLAMA_SUMMARY_TIMEOUT_MS || 90_000)),
  );
}

async function ollamaComplete(system, user, lang = 'en', timeoutMs = null) {
  const model = ollamaModelForLanguage(lang);
  if (useOllamaChatApi()) {
    return ollamaChat(system, user, lang, timeoutMs ?? ollamaTimeoutMs());
  }
  const url = `${ollamaBaseUrl()}/api/generate`;
  const ac = new AbortController();
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
          num_predict: Number(process.env.OLLAMA_MAX_TOKENS || 150),
        },
      }),
      signal: ac.signal,
    });
    if (!response.ok) throw new Error(`Ollama ${response.status}`);
    const data = await response.json();
    return cleanModelOutput(data?.response || '');
  } finally {
    clearTimeout(timer);
  }
}

async function ollamaCompleteQueued(system, user, lang = 'en', timeoutMs = null) {
  return withOllamaIngestionQueue(() => ollamaComplete(system, user, lang, timeoutMs));
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
    if (isOllamaProvider()) {
      try {
        const model = ollamaModelForLanguage('en');
        const raw = await ollamaCompleteQueued(
          summarySystemPrompt('en'),
          summaryUserPrompt(input),
          'en',
          ollamaSummaryTimeoutMs(),
        );
        const out = validateLanguageOutput(raw, 'en');
        if (out) return out;
      } catch (e) {
        console.error(`[ai] English Ollama summarization failed: ${e.message}`);
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
        const raw = await ollamaCompleteQueued(
          summarySystemPrompt(lang),
          summaryUserPrompt(input),
          lang,
          ollamaSummaryTimeoutMs(),
        );
        const out = validateLanguageOutput(raw, lang);
        if (out) return out;
        console.warn(
          `[ai] Ollama summary rejected (lang=${lang}, model=${model}). Trying HF backup...`,
        );
      } catch (e) {
        console.error(`Ollama summarization failed: ${e.message || e}. Trying HF backup...`);
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
    const out = await withOllamaIngestionQueue(() => ollamaChat(system, user, lang));
    return /^yes\b/i.test(String(out || '').trim());
  } catch {
    return false;
  }
}

async function pingOllama() {
  if (!isOllamaProvider()) return { ok: false, skipped: true };
  try {
    const res = await fetch(`${ollamaBaseUrl()}/api/tags`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}` };
    const data = await res.json();
    const installed = (data?.models || []).map((m) => m.name);
    const required = getConfiguredOllamaModels();
    const missing = required.filter(
      (name) => !installed.some((n) => n === name || n.startsWith(`${name}:`)),
    );
    return {
      ok: missing.length === 0,
      models: installed,
      required,
      missing,
      modelsByLang: {
        en: ollamaModelForLanguage('en'),
        hi: ollamaModelForLanguage('hi'),
        te: ollamaModelForLanguage('te'),
      },
    };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function isOllamaAbortError(err) {
  const msg = String(err?.message || err || '');
  return err?.name === 'AbortError' || /aborted|timeout|timed out/i.test(msg);
}

async function chatWithOllama(systemPrompt, userPrompt, lang = 'en') {
  if (!isOllamaProvider()) {
    throw new Error('Ollama provider is not enabled in environment');
  }
  return withOllamaChatQueue(() =>
    ollamaChat(systemPrompt, userPrompt, lang, ollamaChatTimeoutMs()),
  );
}

module.exports = {
  getAiProvider,
  isOllamaProvider,
  isAiSummaryEnabled,
  summarize,
  translateToEnglish,
  translateToFeedLanguage,
  pingOllama,
  ollamaModelForLanguage,
  getConfiguredOllamaModels,
  validateLanguageOutput,
  cleanModelOutput,
  areTitlesSameStory,
  chatWithOllama,
  ollamaChatTimeoutMs,
  ollamaSummaryTimeoutMs,
  isOllamaAbortError,
  withOllamaChatQueue,
  withOllamaIngestionQueue,
};
