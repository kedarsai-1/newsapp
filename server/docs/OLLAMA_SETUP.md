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
ollama pull gemma2:2b
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

## 4. Limit loaded models (single VPS)

On an 11 GB VPS running **chat** (`gemma2:2b`) and **ingest** (`mashriram/sarvam-1`) together, allow **two** models in RAM so chat and ingest do not swap on every request:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/max-loaded-models.conf <<'EOF'
[Service]
Environment="OLLAMA_MAX_LOADED_MODELS=2"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

If RAM is tight, use `OLLAMA_MAX_LOADED_MODELS=1` — chat and ingest will serialize at the Ollama layer.

Verify loaded models during ingest + chat:

```bash
curl -s http://127.0.0.1:11434/api/ps | jq .
```

## 4b. Separate chat vs ingest models (recommended)

Chat and ingest use **different model env vars**:

| Purpose | Env vars | Default |
|---------|----------|---------|
| **Ingest summaries** | `OLLAMA_MODEL_EN`, `OLLAMA_MODEL_INDIC`, `OLLAMA_MODEL_HI/TE` | `llama3.1:8b` / `mashriram/sarvam-1` |
| **User chat** | `OLLAMA_MODEL_CHAT`, `OLLAMA_MODEL_CHAT_EN/HI/TE` | `gemma2:2b` (all langs) |

Production two-model setup on one Ollama instance (fast chat + Indic ingest):

```env
OLLAMA_MODEL_EN=llama3.1:8b
OLLAMA_MODEL_INDIC=mashriram/sarvam-1
OLLAMA_MODEL_CHAT=gemma2:2b
OLLAMA_MAX_LOADED_MODELS=2   # systemd — keeps gemma2:2b + sarvam-1 hot
```

Optional: run a second Ollama on `:11435` for chat only (needs extra RAM — do not run two full instances on 11 GB under load):

```env
OLLAMA_CHAT_BASE_URL=http://127.0.0.1:11435
```

When chat and ingest share one Ollama URL (default), the app:

- Routes **chat** to `OLLAMA_MODEL_CHAT*` (`gemma2:2b`)
- Routes **ingest** to `OLLAMA_MODEL_*` / `OLLAMA_MODEL_INDIC` (`sarvam-1`, etc.)
- Uses a **chat-priority scheduler** (one inference at a time)
- **Preempts in-flight ingest** Ollama calls when a user opens chat
- Skips queued ingest AI while chat is waiting (`OLLAMA_INGEST_YIELD_TO_CHAT`, default on)

Do **not** set `OLLAMA_MODEL_EN=gemma2:2b` for ingest if chat uses `gemma2:2b` — use `llama3.1:8b` for English ingest summaries instead.

## 5. Start services

```bash
sudo systemctl enable ollama
sudo systemctl start ollama
cd server && npm start
```

On startup you should see:

`[ai] Ollama ready ingest en=... hi=mashriram/sarvam-1 te=mashriram/sarvam-1 | chat en=gemma2:2b hi=gemma2:2b te=gemma2:2b`

**Health check** (cached 60s by default):

```bash
curl -s http://127.0.0.1:5001/api/health | jq .ai
curl -s 'http://127.0.0.1:5001/api/health?refresh=1' | jq .ai
```

If a model is missing, logs list `missing` models and summaries fall back to extractive text until you `ollama pull` them.

## 6. How ingest uses Ollama

| Language | Model (default) | Behavior |
|----------|-----------------|----------|
| English | `llama3.1:8b` | 1 chat call → validated English summary |
| Hindi | `mashriram/sarvam-1` | 1 chat call in Hindi → Devanagari validation |
| Telugu | `mashriram/sarvam-1` | 1 chat call in Telugu → Telugu script validation |

Bad Ollama output → extractive summary fallback (no crash). Requests are queued (one at a time) to avoid OOM on 11 GB RAM.

## 7. Security

- Ollama on `127.0.0.1:11434` only — do not expose publicly.

## 8. Tuning

```env
OLLAMA_TEMPERATURE=0.1
OLLAMA_WARM_LANGS=en,hi,te
RSS_INSERTS_PER_FEED=4
INGEST_MAX_RUNTIME_MS=400000
INGEST_PARALLEL_LANGUAGES=false
SCRAPER_CRON_EN=*/15 * * * *
SCRAPER_CRON_HI=5-59/15 * * * *
SCRAPER_CRON_TE=10-59/15 * * * *
```

## 9. Switch back to Hugging Face

```env
AI_PROVIDER=huggingface
HF_TOKEN=your_token
```

HF Indic path still uses translate → summarize → translate (3 API calls) when `RSS_INDIC_AI_SUMMARY=true`.
