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

let ollamaQueue = Promise.resolve();

function withOllamaQueue(fn) {
  const run = ollamaQueue.then(fn, fn);
  ollamaQueue = run.catch(() => {});
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
    180000,
    Math.max(10000, Number(process.env.OLLAMA_TIMEOUT_MS || 90000)),
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
  let t = String(text || '')
    .replace(/^summary:\s*/i, '')
    .replace(/^translation:\s*/i, '')
    .replace(/^["']|["']$/g, '')
    .trim();

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

  return t.length > 320 ? `${t.slice(0, 317).trim()}…` : t;
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

async function ollamaChat(system, user, lang = 'en') {
  const url = `${ollamaBaseUrl()}/api/chat`;
  const model = ollamaModelForLanguage(lang);
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), ollamaTimeoutMs());
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

async function ollamaComplete(system, user, lang = 'en') {
  const model = ollamaModelForLanguage(lang);
  if (useOllamaChatApi()) {
    return ollamaChat(system, user, lang);
  }
  const url = `${ollamaBaseUrl()}/api/generate`;
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), ollamaTimeoutMs());
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

async function ollamaCompleteQueued(system, user, lang = 'en') {
  return withOllamaQueue(() => ollamaComplete(system, user, lang));
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
  const result = await hfFetch('sshleifer/distilbart-cnn-12-6', text);
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
  const input = String(text || '').slice(0, 512);
  const result = await hfFetch('facebook/nllb-200-distilled-600M', input, {
    parameters: { src_lang: 'eng_Latn', tgt_lang: 'tel_Telu' },
  });
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

  if (isOllamaProvider()) {
    try {
      const model = ollamaModelForLanguage(lang);
      const raw = await ollamaCompleteQueued(
        summarySystemPrompt(lang),
        summaryUserPrompt(input),
        lang,
      );
      const out = validateLanguageOutput(raw, lang);
      if (!out) {
        console.warn(
          `[ai] Ollama summary rejected (lang=${lang}, model=${model}). `
            + 'Check script validation or try mashriram/sarvam-1 for te/hi.',
        );
      }
      return out;
    } catch (e) {
      throw new Error(`Ollama summarization failed: ${e.message || e}`);
    }
  }

  let summaryEn = await summarizeWithHf(input);
  if (!summaryEn) return '';
  if (lang === 'hi' || lang === 'te') {
    const tr = await translateToFeedLanguage(summaryEn, lang);
    if (tr?.trim()) return tr.trim();
  }
  return summaryEn;
}

async function translateToEnglish(text) {
  const raw = String(text || '').trim();
  if (!raw) return '';
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
      return out || raw;
    } catch {
      return raw;
    }
  }
  try {
    return await translateToEnglishWithHf(raw);
  } catch {
    return raw;
  }
}

async function translateToFeedLanguage(text, targetLang) {
  const raw = String(text || '').trim();
  const target = String(targetLang || '').toLowerCase();
  if (!raw || !['en', 'hi', 'te'].includes(target)) return raw;

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
      return out || raw;
    } catch {
      return raw;
    }
  }

  try {
    if (target === 'hi') {
      const out = await translateEnglishToHindiWithHf(raw);
      return out || raw;
    }
    if (target === 'te') {
      const out = await translateEnglishToTeluguWithHf(raw);
      return out || raw;
    }
  } catch {
    return raw;
  }
  return raw;
}

/** Health check for startup logs / ops. */
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
};
