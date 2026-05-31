# Ollama on Contabo VPS (Option A — Node + Ollama same server)

## Tokens / cost (Telugu & Hindi)

**Ollama on your VPS has no per-token billing.** You pay for RAM and CPU time, not Hugging Face quota.

| Path | Calls per article | Notes |
|------|-------------------|--------|
| **Ollama (this app)** | **1** chat call | Summary written directly in `en` / `hi` / `te` |
| Old HF Indic path | 3 calls | translate → EN → summarize → translate back |

Telugu and Hindi text can be **longer in characters** than English for the same meaning, so each request may take a bit more **time** on CPU — not “more tokens” in a paid sense. With `RSS_INDIC_AI_SUMMARY=true` and `AI_PROVIDER=ollama`, hi/te use **one** Ollama call each.

## Recommended models (11 GB RAM, no GPU)

| Language | Model | Why |
|----------|--------|-----|
| **English** | `llama3.1:8b` | Stable English; avoids Chinese drift from Qwen |
| **Hindi + Telugu** | `mashriram/sarvam-1` | Sarvam-1 (2B), trained for 10 Indic languages including hi/te |
| Fallback Indic | `aya:8b` | Multilingual if Sarvam-1 is unavailable |

Avoid **`qwen2.5:7b`** for English — often mixes Chinese and `(Note:...)` meta text.

## 1. Install Ollama and pull models

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b
ollama pull mashriram/sarvam-1
```

Optional fallback:

```bash
ollama pull aya:8b
# then set OLLAMA_MODEL_INDIC=aya:8b
```

## 2. Verify

```bash
curl http://127.0.0.1:11434/api/tags
```

English test:

```bash
curl http://127.0.0.1:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "stream": false,
  "messages": [
    {"role": "system", "content": "Reply with ONE short summary in English only. Max 280 chars. No notes, no Chinese."},
    {"role": "user", "content": "Article:\nIndia PM announced a new policy on digital rupee.\n\nSummary:"}
  ]
}'
```

Telugu test (use Sarvam, not Llama, for best script quality):

```bash
curl http://127.0.0.1:11434/api/chat -d '{
  "model": "mashriram/sarvam-1",
  "stream": false,
  "messages": [
    {"role": "system", "content": "Reply with ONE short summary in Telugu only. Telugu script only. Max 280 chars. No notes."},
    {"role": "user", "content": "Article:\n<paste Telugu text>\n\nSummary:"}
  ]
}'
```

If output has Chinese, `(Note:...)`, or wrong script, the **app rejects it** and uses extractive fallback.

## 3. Server env (`server/.env`)

```env
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3.1:8b
OLLAMA_MODEL_EN=llama3.1:8b
OLLAMA_MODEL_INDIC=mashriram/sarvam-1
OLLAMA_TIMEOUT_MS=90000
RSS_INDIC_AI_SUMMARY=true
```

Optional overrides per language:

```env
OLLAMA_MODEL_HI=mashriram/sarvam-1
OLLAMA_MODEL_TE=mashriram/sarvam-1
```

## 4. Start services

```bash
sudo systemctl enable ollama
sudo systemctl start ollama
cd server && npm start
```

On startup you should see:

`[ai] Ollama ready en=llama3.1:8b hi=mashriram/sarvam-1 te=mashriram/sarvam-1`

**Health check** (cached 60s by default):

```bash
curl -s http://127.0.0.1:5001/api/health | jq .ai
curl -s 'http://127.0.0.1:5001/api/health?refresh=1' | jq .ai
```

If a model is missing, logs list `missing` models and summaries fall back to extractive text until you `ollama pull` them.

## 5. How ingest uses Ollama

| Language | Model (default) | Behavior |
|----------|-----------------|----------|
| English | `llama3.1:8b` | 1 chat call → validated English summary |
| Hindi | `mashriram/sarvam-1` | 1 chat call in Hindi → Devanagari validation |
| Telugu | `mashriram/sarvam-1` | 1 chat call in Telugu → Telugu script validation |

Bad Ollama output → extractive summary fallback (no crash). Requests are queued (one at a time) to avoid OOM on 11 GB RAM.

## 6. Security

- Ollama on `127.0.0.1:11434` only — do not expose publicly.

## 7. Tuning

```env
OLLAMA_TEMPERATURE=0.1
RSS_INSERTS_PER_FEED=4
INGEST_MAX_RUNTIME_MS=400000
```

## 8. Switch back to Hugging Face

```env
AI_PROVIDER=huggingface
HF_TOKEN=your_token
```

HF Indic path still uses translate → summarize → translate (3 API calls) when `RSS_INDIC_AI_SUMMARY=true`.
