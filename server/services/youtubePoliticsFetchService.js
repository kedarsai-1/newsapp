/**
 * Fetch latest YouTube uploads — metadata only (no video download).
 */
const {
  isYoutubeQuotaBlocked,
  isYoutubeQuotaError,
  markYoutubeQuotaBlocked,
} = require('../utils/youtubeQuota');

const YOUTUBE_API_BASE = 'https://www.googleapis.com/youtube/v3';

async function youtubeGet(path, params) {
  const key = process.env.YOUTUBE_API_KEY?.trim();
  if (!key) throw new Error('YOUTUBE_API_KEY is not set');
  const qs = new URLSearchParams({ ...params, key });
  const url = `${YOUTUBE_API_BASE}/${path}?${qs.toString()}`;
  const res = await fetch(url, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(Number(process.env.YOUTUBE_API_TIMEOUT_MS || 20000)),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data?.error?.message || res.statusText || `HTTP ${res.status}`;
    const err = new Error(`YouTube API ${path}: ${msg}`);
    throw err;
  }
  return data;
}

function pickThumbnail(snippet) {
  const thumbs = snippet?.thumbnails || {};
  return (
    thumbs.maxres?.url
    || thumbs.standard?.url
    || thumbs.high?.url
    || thumbs.medium?.url
    || thumbs.default?.url
    || null
  );
}

function normalizeSnippetItem(snippet, videoId, channelMeta = {}) {
  const title = String(snippet?.title || '').trim();
  if (!title || /private video|deleted video/i.test(title)) return null;
  return {
    videoId,
    title: title.slice(0, 200),
    description: String(snippet?.description || '').slice(0, 2000),
    thumbnail: pickThumbnail(snippet),
    publishedAt: snippet?.publishedAt ? new Date(snippet.publishedAt) : new Date(),
    channelName: String(
      snippet?.channelTitle || channelMeta.name || 'YouTube',
    ).slice(0, 120),
    channelId: snippet?.channelId || channelMeta.channelId || null,
    language: channelMeta.language || 'en',
  };
}

async function getUploadsPlaylistId(channelId) {
  const data = await youtubeGet('channels', {
    part: 'contentDetails',
    id: channelId,
  });
  return data.items?.[0]?.contentDetails?.relatedPlaylists?.uploads || null;
}

/**
 * Latest uploads from a channel — snippet fields only (1 playlist + optional status batch).
 */
async function fetchChannelLatestVideos(channel, maxResults = 15) {
  if (isYoutubeQuotaBlocked()) return [];

  const uploadsPlaylistId = await getUploadsPlaylistId(channel.channelId);
  if (!uploadsPlaylistId) return [];

  const data = await youtubeGet('playlistItems', {
    part: 'snippet',
    playlistId: uploadsPlaylistId,
    maxResults: String(Math.min(50, Math.max(1, maxResults))),
  });

  const out = [];
  for (const item of data.items || []) {
    const videoId = item?.snippet?.resourceId?.videoId;
    if (!videoId) continue;
    const row = normalizeSnippetItem(item.snippet, videoId, channel);
    if (row) out.push(row);
  }
  return out;
}

/** Batch check embeddable + public (minimal quota). */
async function filterEmbeddableVideos(videos) {
  if (!videos.length) return [];
  const embeddable = [];
  const chunkSize = 50;

  for (let i = 0; i < videos.length; i += chunkSize) {
    const chunk = videos.slice(i, i + chunkSize);
    const ids = chunk.map((v) => v.videoId).join(',');
    try {
      // eslint-disable-next-line no-await-in-loop
      const data = await youtubeGet('videos', {
        part: 'status,contentDetails',
        id: ids,
      });
      const statusMap = new Map((data.items || []).map((v) => [v.id, v]));
      for (const v of chunk) {
        const meta = statusMap.get(v.videoId);
        if (!meta) continue;
        if (meta.status?.embeddable === false) continue;
        if (meta.status?.privacyStatus !== 'public') continue;
        embeddable.push(v);
      }
    } catch (e) {
      if (isYoutubeQuotaError(e)) throw e;
      console.warn('[youtube-politics] embeddable check failed:', e.message);
      embeddable.push(...chunk);
    }
  }
  return embeddable;
}

async function fetchLatestFromChannels(channels, maxPerChannel = 15) {
  const merged = [];
  for (const channel of channels) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const rows = await fetchChannelLatestVideos(channel, maxPerChannel);
      merged.push(...rows);
    } catch (e) {
      if (isYoutubeQuotaError(e)) {
        markYoutubeQuotaBlocked();
        throw e;
      }
      console.warn(
        `[youtube-politics] channel ${channel.channelId} failed:`,
        e.message,
      );
    }
  }
  return merged;
}

module.exports = {
  fetchLatestFromChannels,
  fetchChannelLatestVideos,
  filterEmbeddableVideos,
};
