const crypto = require('crypto');
const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Category = require('../models/Category');
const {
  fetchNewsApiItems,
  fetchGNewsItems,
  fetchBestImageFallback,
  buildDomainImageFallbackCandidates,
} = require('./newsApiService');
const { newsApiIngestPlan } = require('../config/newsApiIngestPlan');
const { cloudinary } = require('../config/cloudinary');
const { getRssFeeds } = require('../config/rssFeeds');
const {
  fetchRssItems,
  normalizeRssItem,
  resolveGoogleNewsPublisherUrl,
  summarizeInputFromItem,
  prepareForHfSummaryFromRssItem,
  prepareForSummarization,
  summarizeForRssIngest,
  translateEnglishToFeedLanguage,
} = require('./rssService');
const { extractReadableArticle } = require('./articleExtractionService');

let ingestState = {
  isRunning: false,
  lastRunAt: null,
  lastSuccessAt: null,
  lastSummary: null,
  lastError: null,
};

const SYSTEM_REPORTER_EMAIL = process.env.SCRAPER_SYSTEM_EMAIL || 'scraper@newsnow.local';
const SYSTEM_REPORTER_PASSWORD = process.env.SCRAPER_SYSTEM_PASSWORD || 'change_me_123';
const DEFAULT_CATEGORY_SLUG = process.env.SCRAPER_DEFAULT_CATEGORY || 'general';
const SCRAPER_AUTO_APPROVE = process.env.SCRAPER_AUTO_APPROVE !== 'false';
const NEWSAPI_MULTI_CATEGORY = process.env.NEWSAPI_MULTI_CATEGORY !== 'false';
const INGEST_REHOST_IMAGES = process.env.INGEST_REHOST_IMAGES !== 'false';

function hashUrl(url) {
  return crypto.createHash('sha256').update(url).digest('hex');
}

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

async function rehostExternalImageToCloudinary(imageUrl, { referer } = {}) {
  if (!INGEST_REHOST_IMAGES) return { ok: false, reason: 'disabled' };
  if (!imageUrl || typeof imageUrl !== 'string') return { ok: false, reason: 'missing' };
  if (isCloudinaryUrl(imageUrl)) return { ok: true, url: imageUrl, already: true };

  let parsed;
  try {
    parsed = new URL(imageUrl.trim());
  } catch {
    return { ok: false, reason: 'invalid_url' };
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return { ok: false, reason: 'scheme' };
  if (isBlockedFetchHost(parsed.hostname)) return { ok: false, reason: 'blocked_host' };

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 15000);
  try {
    const headers = {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (referer && typeof referer === 'string' && referer.trim()) {
      headers.Referer = referer.trim();
      headers.Origin = referer.trim();
    }

    const res = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers,
    });
    clearTimeout(to);
    if (!res.ok) return { ok: false, reason: `http_${res.status}` };

    const ct = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (ct && !ct.startsWith('image/')) return { ok: false, reason: `not_image_${ct}` };

    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length) return { ok: false, reason: 'empty' };
    if (buf.length > 5 * 1024 * 1024) return { ok: false, reason: 'too_large' };

    const ext =
      ct === 'image/png' ? 'png'
      : ct === 'image/webp' ? 'webp'
      : ct === 'image/gif' ? 'gif'
      : ct === 'image/avif' ? 'avif'
      : 'jpg';

    const dataUri = `data:${ct || 'image/jpeg'};base64,${buf.toString('base64')}`;
    const upload = await cloudinary.uploader.upload(dataUri, {
      folder: 'newsapp/external',
      resource_type: 'image',
      overwrite: false,
      unique_filename: true,
      format: ext,
    });
    const secure = upload?.secure_url || upload?.url;
    if (!secure) return { ok: false, reason: 'upload_failed' };
    return { ok: true, url: secure, publicId: upload.public_id };
  } catch (e) {
    clearTimeout(to);
    const msg = e?.name === 'AbortError' ? 'timeout' : 'fetch_failed';
    return { ok: false, reason: msg };
  }
}

async function ensureSystemReporter() {
  let reporter = await User.findOne({ email: SYSTEM_REPORTER_EMAIL });
  if (!reporter) {
    reporter = await User.create({
      name: 'News Ingestion Bot',
      email: SYSTEM_REPORTER_EMAIL,
      password: SYSTEM_REPORTER_PASSWORD,
      role: 'reporter',
      isVerified: true,
    });
  }
  return reporter;
}

async function getCategoryBySlug(slug) {
  let category = await Category.findOne({ slug: slug || DEFAULT_CATEGORY_SLUG, isActive: true });
  if (!category) {
    category = await Category.findOne({ isActive: true }).sort({ order: 1, createdAt: 1 });
  }
  if (!category) {
    throw new Error('No active category found. Seed categories before running ingestion.');
  }
  return category;
}

async function isDuplicate(item) {
  if (item.sourceUrl) {
    const sourceUrlHash = hashUrl(item.sourceUrl);
    const existsByHash = await NewsPost.exists({ sourceUrlHash });
    if (existsByHash) return true;
  }

  const fuzzyWindowStart = new Date(Date.now() - 48 * 60 * 60 * 1000);
  const existsByTitle = await NewsPost.exists({
    title: item.title,
    createdAt: { $gte: fuzzyWindowStart },
  });
  return !!existsByTitle;
}

function toPostDoc(item, reporterId, categoryId, sourceName) {
  return {
    title: item.title.slice(0, 200),
    body: item.body || item.title,
    summary: item.summary,
    reporter: reporterId,
    category: categoryId,
    media: item.mediaUrl ? [{ type: 'image', url: item.mediaUrl }] : [],
    status: SCRAPER_AUTO_APPROVE ? 'approved' : 'pending',
    approvedAt: SCRAPER_AUTO_APPROVE ? new Date() : null,
    tags: item.tags || [],
    language: item.language || 'en',
    originalLanguage: item.originalLanguage || null,
    sourceName,
    sourceUrl: item.sourceUrl || null,
    sourceUrlHash: item.sourceUrl ? hashUrl(item.sourceUrl) : null,
    sourcePublishedAt: item.sourcePublishedAt ? new Date(item.sourcePublishedAt) : null,
    sourceType: item.sourceType,
    scrapedAt: new Date(),
    scrapeConfidence: item.scrapeConfidence,
  };
}

function summarizeForPost(text) {
  const t = String(text || '').replace(/\s+/g, ' ').trim();
  if (!t) return null;
  return t.length > 280 ? `${t.slice(0, 277)}...` : t;
}

function getIngestPlans() {
  if (!NEWSAPI_MULTI_CATEGORY) {
    return [{ categorySlug: DEFAULT_CATEGORY_SLUG, newsApiCategory: null }];
  }
  return newsApiIngestPlan;
}

/** GNews runs once per language so Telugu/Hindi feeds get fresh items, not only legacy RSS rows. */
function getGNewsIngestLanguages() {
  const raw = process.env.GNEWS_INGEST_LANGS?.trim();
  if (raw) {
    return raw
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean);
  }
  return ['en', 'te', 'hi'];
}

async function runIngestion({ triggeredBy = 'scheduler' } = {}) {
  if (ingestState.isRunning) {
    return {
      success: false,
      skipped: true,
      message: 'Ingestion already running.',
      state: ingestState,
    };
  }

  ingestState.isRunning = true;
  ingestState.lastRunAt = new Date();
  ingestState.lastError = null;

  const stats = {
    triggeredBy,
    startedAt: new Date(),
    fetched: 0,
    inserted: 0,
    duplicates: 0,
    failed: 0,
    fallbacks: 0,
    sourceRuns: [],
  };

  try {
    const useGNews = Boolean(process.env.GNEWS_API_KEY?.trim());
    const useNewsApi = Boolean(process.env.NEWSAPI_KEY?.trim());
    if (!useGNews && !useNewsApi) {
      const msg =
        'Set GNEWS_API_KEY (recommended) or NEWSAPI_KEY in the server environment.';
      ingestState.lastError = msg;
      stats.endedAt = new Date();
      return { success: false, error: msg, stats };
    }

    const fetchItems = useGNews ? fetchGNewsItems : fetchNewsApiItems;
    const providerLabel = useGNews ? 'GNews' : 'NewsAPI';

    const ingestLanguages = useGNews
      ? getGNewsIngestLanguages()
      : [(process.env.NEWSAPI_LANGUAGE || 'en').toLowerCase()];

    const reporter = await ensureSystemReporter();
    const plans = getIngestPlans();
    const perRequest = Math.min(
      100,
      Math.max(
        4,
        Number(
          process.env.GNEWS_ITEMS_PER_CATEGORY
            || process.env.NEWSAPI_ITEMS_PER_CATEGORY
            || Math.ceil(36 / Math.max(plans.length, 1)),
        ),
      ),
    );

    for (const ingestLang of ingestLanguages) {
      for (const plan of plans) {
        let category;
        try {
          category = await getCategoryBySlug(plan.categorySlug);
        } catch {
          stats.sourceRuns.push({
            source: `${providerLabel}:${ingestLang}:${plan.categorySlug}`,
            success: false,
            error: `Category slug "${plan.categorySlug}" not found; seed categories.`,
          });
          continue;
        }

        const apiLabel = plan.newsApiCategory ?? 'mixed';
        try {
          const items = await fetchItems({
            newsApiCategory: plan.newsApiCategory,
            pageSize: perRequest,
            ...(useGNews ? { language: ingestLang } : {}),
          });
          stats.fetched += items.length;

          for (const item of items) {
            if (!item.title) {
              stats.failed += 1;
              continue;
            }
            if (await isDuplicate(item)) {
              stats.duplicates += 1;
              continue;
            }

          // Re-host external thumbnails on Cloudinary for reliability (no hotlink blocking).
          let postFields = item;
          if (item.mediaUrl) {
            const reh = await rehostExternalImageToCloudinary(item.mediaUrl, {
              referer: item.sourceUrl || null,
            });
            if (reh.ok && reh.url) {
              postFields = { ...item, mediaUrl: reh.url };
            }
          }

            const label = `${providerLabel} · ${item.apiSourceName || 'headlines'}`;
          const { apiSourceName, ...postDocFields } = postFields;
          await NewsPost.create(toPostDoc(postDocFields, reporter._id, category._id, label));
            stats.inserted += 1;
          }

          stats.sourceRuns.push({
            source: `${providerLabel}:${ingestLang}:${plan.categorySlug}/${apiLabel}`,
            mode: 'api',
            count: items.length,
            success: true,
          });
        } catch (error) {
          stats.failed += 1;
          stats.sourceRuns.push({
            source: `${providerLabel}:${ingestLang}:${plan.categorySlug}/${apiLabel}`,
            success: false,
            error: error.message,
          });
        }
      }
    }

    // RSS ingestion (second source): reliable thumbnails + extra coverage.
    const rssEnabled = process.env.RSS_ENABLED !== 'false';
    if (rssEnabled) {
      const feeds = getRssFeeds();
      for (const feed of feeds) {
        if (!feed?.url) continue;
        let category;
        try {
          category = await getCategoryBySlug(feed.categorySlug || DEFAULT_CATEGORY_SLUG);
        } catch {
          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            success: false,
            error: `Category slug "${feed.categorySlug}" not found; seed categories.`,
          });
          continue;
        }

        try {
          const items = await fetchRssItems(feed.url);
          const maxPerFeed = Math.min(
            50,
            Math.max(5, Number(process.env.RSS_ITEMS_PER_FEED || 20)),
          );
          const slice = items.slice(0, maxPerFeed);
          stats.fetched += slice.length;

          for (const raw of slice) {
            const item = normalizeRssItem(raw, feed);
            if (!item.title) {
              stats.failed += 1;
              continue;
            }
            if (await isDuplicate(item)) {
              stats.duplicates += 1;
              continue;
            }

            const prep = prepareForHfSummaryFromRssItem(raw);
            const summaryInput = prep.textForSummary;
            const originalLang = prep.originalLang;
            const fallbackSummary = String(item.summary || summarizeInputFromItem(raw)).slice(0, 150).trim();
            let displayTitle = item.title;
            if (
              ['hi', 'te'].includes(String(feed.language || '').toLowerCase())
              && originalLang === 'eng'
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const tr = await translateEnglishToFeedLanguage(
                  String(item.title || '').slice(0, 400),
                  feed.language,
                );
                if (tr && tr.trim()) displayTitle = tr.slice(0, 200);
              } catch { /* keep RSS title */ }
            }

            let summaryPrimary = '';
            if (summaryInput) {
              try {
                // eslint-disable-next-line no-await-in-loop
                summaryPrimary = await summarizeForRssIngest(
                  summaryInput,
                  originalLang,
                  feed.language || '',
                );
              } catch (e) {
                summaryPrimary = '';
                stats.fallbacks += 1;
                console.warn(
                  `[rss] summary fallback (${feed.name || 'RSS'}): ${e?.message || e}`,
                );
              }
            }

            let postFields = {
              ...item,
              title: displayTitle,
              summary: summaryPrimary || fallbackSummary || item.summary,
              originalLanguage: originalLang,
            };

            // Google News RSS items often point to news.google.com redirect pages.
            // Resolve to the real publisher URL so:
            // - thumbnails come from the publisher (not Google News logo)
            // - full-article extraction works reliably
            if (
              feed.resolvePublisherUrl
              && postFields.sourceUrl
              && String(postFields.sourceUrl).includes('news.google.com')
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const resolved = await resolveGoogleNewsPublisherUrl(postFields.sourceUrl, {
                  preferredHost: feed.preferredHost || null,
                });
                if (resolved) {
                  postFields = { ...postFields, sourceUrl: resolved };
                }
              } catch { /* ignore */ }
            }

            // Some RSS (notably Google News RSS) has no enclosure/media tags. Try og:image from the article page.
            if (
              !postFields.mediaUrl
              && feed.ogImageFallback
              && process.env.RSS_OG_FALLBACK !== 'false'
              && postFields.sourceUrl
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const og = await fetchBestImageFallback(postFields.sourceUrl);
                if (og) postFields = { ...postFields, mediaUrl: og };
              } catch { /* ignore */ }
            }

            // RSS feeds sometimes provide only a one-line snippet.
            // Enrich short bodies from the source URL so article detail isn't one-liner.
            const shouldEnrichBody =
              process.env.RSS_ENRICH_BODY !== 'false'
              && postFields.sourceUrl
              && String(postFields.body || '').trim().length < 260;
            if (shouldEnrichBody) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const ext = await extractReadableArticle(postFields.sourceUrl, {
                  timeoutMs: Number(process.env.RSS_ENRICH_TIMEOUT_MS || 9000),
                  maxBytes: Number(process.env.RSS_ENRICH_MAX_BYTES || 900000),
                  cacheTtlMs: Number(process.env.RSS_ENRICH_CACHE_TTL_MS || 30 * 60 * 1000),
                });
                const full = String(ext?.text || '').replace(/\s+/g, ' ').trim();
                if (ext?.success && full.length > 320) {
                  let summaryAfterEnrich = (summaryPrimary && String(summaryPrimary).trim())
                    ? String(summaryPrimary).trim()
                    : null;
                  if (!summaryAfterEnrich) {
                    const chunk = full.slice(0, 1000).trim();
                    if (chunk.length >= 40) {
                      try {
                        const prepChunk = prepareForSummarization(chunk);
                        if (prepChunk.textForSummary.length >= 40) {
                          // eslint-disable-next-line no-await-in-loop
                          const s2 = await summarizeForRssIngest(
                            prepChunk.textForSummary,
                            prepChunk.originalLang,
                            feed.language || '',
                          );
                          if (s2 && String(s2).trim()) summaryAfterEnrich = String(s2).trim();
                        }
                        if (
                          (!postFields.originalLanguage || postFields.originalLanguage === 'und')
                          && prepChunk.originalLang
                          && prepChunk.originalLang !== 'und'
                        ) {
                          postFields = { ...postFields, originalLanguage: prepChunk.originalLang };
                        }
                      } catch (e) {
                        stats.fallbacks += 1;
                        console.warn(
                          `[rss] summary after enrich (${feed.name || 'RSS'}): ${e?.message || e}`,
                        );
                      }
                    }
                  }
                  if (!summaryAfterEnrich) summaryAfterEnrich = summarizeForPost(full);
                  postFields = {
                    ...postFields,
                    body: full.slice(0, 10000),
                    summary: summaryAfterEnrich,
                  };
                }
              } catch { /* ignore */ }
            }

            // Last-resort thumbnail so cards never look empty when publisher blocks article images.
            if (!postFields.mediaUrl && postFields.sourceUrl) {
              const fallbackCandidates = buildDomainImageFallbackCandidates(postFields.sourceUrl);
              for (const candidate of fallbackCandidates) {
                // eslint-disable-next-line no-await-in-loop
                const reh = await rehostExternalImageToCloudinary(candidate, {
                  referer: postFields.sourceUrl || feed.url || null,
                });
                if (reh.ok && reh.url) {
                  postFields = { ...postFields, mediaUrl: reh.url };
                  break;
                }
              }
            }

            if (postFields.mediaUrl) {
              const reh = await rehostExternalImageToCloudinary(postFields.mediaUrl, {
                referer: postFields.sourceUrl || feed.url || null,
              });
              if (reh.ok && reh.url) {
                postFields = { ...postFields, mediaUrl: reh.url };
              }
            }

            const label = `RSS · ${feed.name || 'RSS'}`;
            const { apiSourceName, ...postDocFields } = postFields;
            await NewsPost.create(toPostDoc(postDocFields, reporter._id, category._id, label));
            stats.inserted += 1;
          }

          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            mode: 'rss',
            count: slice.length,
            success: true,
          });
        } catch (error) {
          stats.failed += 1;
          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            success: false,
            error: error.message,
          });
        }
      }
    }

    stats.endedAt = new Date();
    ingestState.lastSuccessAt = stats.endedAt;
    ingestState.lastSummary = stats;
    return { success: true, stats };
  } catch (error) {
    ingestState.lastError = error.message;
    stats.endedAt = new Date();
    return { success: false, error: error.message, stats };
  } finally {
    ingestState.isRunning = false;
  }
}

function getIngestionStatus() {
  return { ...ingestState };
}

module.exports = {
  runIngestion,
  getIngestionStatus,
};
