---
name: News Scraping Pipeline
overview: Implement a hybrid ingestion pipeline that pulls from RSS first and falls back to HTML extraction, then stores scraped stories as pending posts for admin review.
todos:
  - id: define-source-registry
    content: Create source registry/config and ingestion interfaces for RSS and HTML parsers
    status: completed
  - id: implement-rss-ingest
    content: Implement RSS fetch/parse/normalize pipeline with dedupe and pending persistence
    status: completed
  - id: implement-html-fallback
    content: Add HTML extraction fallback for sources without stable RSS parsing
    status: completed
  - id: extend-news-schema
    content: Add source metadata fields to NewsPost model and adjust validation/indexes
    status: completed
  - id: add-scheduler-and-trigger
    content: Wire cron scheduler in server startup and add admin manual-trigger endpoint
    status: completed
  - id: add-ingest-observability
    content: Add structured ingest logs and basic run-status reporting
    status: completed
isProject: false
---

# News Scraping Pipeline Plan

## Goals
- Add automated news ingestion from external sources (RSS + HTML fallback).
- Normalize and deduplicate incoming stories.
- Save scraped stories as `pending` posts so existing admin approval flow controls publication.

## Backend Design
- Create source configuration and ingestion services:
  - Add a source registry (name, url, type, category mapping, language/region, trust level) in a new config/module.
  - Implement RSS fetch/parser service (first attempt path).
  - Implement HTML scraper service (fallback when RSS unavailable or parse fails).
- Normalize each item into internal post shape used by [`/Users/saichaitanya/Desktop/news App/server/models/NewsPost.js`](/Users/saichaitanya/Desktop/news App/server/models/NewsPost.js):
  - title, body/summary, media, sourceUrl, sourceName, category, tags, location hints, publish timestamp.
- Deduplicate before insert:
  - Prefer canonical URL hash + fuzzy title/time fallback.
  - Skip duplicates silently with ingest stats.
- Persist as pending posts:
  - Set `status: 'pending'` to reuse current admin workflow in [`/Users/saichaitanya/Desktop/news App/server/routes/admin.js`](/Users/saichaitanya/Desktop/news App/server/routes/admin.js) and pending moderation screens already in app.
  - Attribute scraped posts to a system reporter account (created/seeded once) for ownership consistency.

## Scheduling & Operations
- Add cron-based scheduler in backend startup [`/Users/saichaitanya/Desktop/news App/server/server.js`](/Users/saichaitanya/Desktop/news App/server/server.js):
  - Run ingest job every N minutes (env-configurable).
  - Add lock/guard to prevent overlapping runs.
- Add admin-only manual trigger endpoint:
  - New route/controller under admin domain for “run now” and status snapshot.
- Add observability:
  - Log fetched/parsed/inserted/duplicate/failed counts per run.
  - Optional lightweight run history collection (Mongo) for troubleshooting.

## API & Data Contract Changes
- Extend post schema with source metadata:
  - `sourceName`, `sourceUrl`, `sourcePublishedAt`, `sourceType`, `scrapedAt`, `scrapeConfidence`.
- Ensure existing feed query logic in [`/Users/saichaitanya/Desktop/news App/server/controllers/newsController.js`](/Users/saichaitanya/Desktop/news App/server/controllers/newsController.js) needs no behavioral change because only `approved` posts are shown to users.

## Admin/App Integration
- Reuse existing pending moderation UI in Flutter (no major UI refactor required).
- Optionally surface source metadata in pending post detail card (small enhancement) in:
  - [`/Users/saichaitanya/Desktop/news App/flutter_app/lib/screens/admin/pending_posts_screen.dart`](/Users/saichaitanya/Desktop/news App/flutter_app/lib/screens/admin/pending_posts_screen.dart)

## Rollout Steps
- Phase 1: RSS ingestion + dedupe + pending persistence.
- Phase 2: HTML fallback for selected sources.
- Phase 3: Admin manual trigger + run metrics endpoint.
- Phase 4: Hardening (timeouts, retries, per-source parser tuning).