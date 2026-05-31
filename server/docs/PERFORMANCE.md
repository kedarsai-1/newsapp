# Backend & app performance

## Already in the project

| Layer | Technique |
|-------|-----------|
| **Feed API** | In-memory TTL cache (pages 1–3, no search); `Cache-Control` + `stale-while-revalidate` |
| **Categories** | 5 min in-memory cache |
| **Single post** | 2 min cache (views still increment) |
| **Invalidation** | Cleared on every `feed_updated` (RSS / YouTube / political ingest) |
| **Sports / CricAPI** | `memoryCache` + stale fallback on rate limit |
| **Article extract** | URL-keyed cache (200 entries, 30 min default) |
| **Political ML** | Embedding prototype cache on disk |
| **Ollama** | One request at a time (queue); per-language models |
| **Flutter feed** | `ListView.builder`, `Selector`, image precache, `memCacheWidth` |
| **Flutter API** | 30s feed page-1 cache, 5 min categories; cleared on socket `feed_updated` |

## Env (Contabo / Railway)

```env
FEED_CACHE_ENABLED=true
FEED_CACHE_TTL_MS=45000
FEED_CACHE_MAX_PAGE=3
CATEGORIES_CACHE_TTL_MS=300000
POST_CACHE_TTL_MS=120000
```

Set `FEED_CACHE_ENABLED=false` while debugging ingest.

## When to add Redis / CDN

- **Multiple Node instances** behind a load balancer → shared cache (Redis) instead of in-process `memoryCache`.
- **Heavy image traffic** → Cloudinary transforms + CDN in front of `proxy-image`.
- **DB hot paths** → Prisma indexes on `status`, `categoryId`, `language`, `sourcePublishedAt` (review `schema.prisma`).

## Ingest performance (not HTTP cache)

- `INGEST_PER_LANGUAGE=true` — staggered crons per language.
- `INGEST_MAX_RUNTIME_MS=400000` on Ollama VPS for hi/te.
- `RSS_INSERTS_PER_FEED` / `RSS_SCAN_PER_FEED` — lower = faster runs, fewer new stories.

## Verify cache

```bash
curl -sI 'http://127.0.0.1:5001/api/news/feed?page=1&limit=20&language=en' | grep -i cache-control
curl -s 'http://127.0.0.1:5001/api/news/feed?page=1&limit=20' | jq .cached
```

Second request within TTL should show `"cached": true`.
