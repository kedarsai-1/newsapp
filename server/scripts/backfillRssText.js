require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const { extractReadableArticle } = require('../services/articleExtractionService');

function cleanText(input) {
  return String(input || '')
    .replace(/&nbsp;|&#160;|&#xa0;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function summarize(text) {
  const t = String(text || '').trim();
  if (!t) return null;
  return t.length > 280 ? `${t.slice(0, 277)}...` : t;
}

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const q = {
    sourceType: 'rss',
    status: 'approved',
    sourceUrl: { $exists: true, $ne: null, $ne: '' },
    $or: [
      { body: /&nbsp;|&#160;|&#xa0;/i },
      { body: { $regex: '^.{0,260}$' } },
    ],
  };
  const posts = await NewsPost.find(q).select('_id body summary sourceUrl').limit(180);
  let cleaned = 0;
  let enriched = 0;
  let failed = 0;

  for (const p of posts) {
    let body = cleanText(p.body);
    let summaryText = cleanText(p.summary);
    let changed = body !== String(p.body || '') || summaryText !== String(p.summary || '');
    if (changed) cleaned += 1;

    if (body.length < 260) {
      try {
        // eslint-disable-next-line no-await-in-loop
        const ext = await extractReadableArticle(p.sourceUrl, {
          timeoutMs: 9000,
          maxBytes: 900000,
          cacheTtlMs: 30 * 60 * 1000,
        });
        const full = cleanText(ext?.text || '');
        if (ext?.success && full.length > 320) {
          body = full.slice(0, 10000);
          summaryText = summarize(full) || summaryText;
          changed = true;
          enriched += 1;
        }
      } catch {
        failed += 1;
      }
    }

    if (changed) {
      p.body = body;
      p.summary = summaryText || null;
      // eslint-disable-next-line no-await-in-loop
      await p.save();
    }
  }

  console.log(JSON.stringify({
    scanned: posts.length, cleaned, enriched, failed,
  }, null, 2));
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});

