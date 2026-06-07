/**
 * Shared in-memory sliding-window rate limit store with stale-bucket pruning.
 */
function createRateLimitStore({
  windowMs = 60_000,
  bucketTtlMs = 120_000,
  cleanupMs = 60_000,
} = {}) {
  const hits = new Map();

  function pruneStaleBuckets() {
    const cutoff = Date.now() - bucketTtlMs;
    for (const [key, bucket] of hits) {
      if (bucket.lastSeen < cutoff) hits.delete(key);
    }
  }

  const cleanupTimer = setInterval(pruneStaleBuckets, cleanupMs);
  if (typeof cleanupTimer.unref === 'function') cleanupTimer.unref();

  function hit(key, maxPerWindow) {
    const now = Date.now();
    let bucket = hits.get(key);
    if (!bucket || now - bucket.start > windowMs) {
      bucket = { start: now, count: 0, lastSeen: now };
      hits.set(key, bucket);
    }
    bucket.count += 1;
    bucket.lastSeen = now;
    return bucket.count <= maxPerWindow;
  }

  function stop() {
    clearInterval(cleanupTimer);
    hits.clear();
  }

  return { hit, stop, _hits: hits, _pruneStaleBuckets: pruneStaleBuckets };
}

module.exports = { createRateLimitStore };
