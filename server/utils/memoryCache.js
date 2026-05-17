/**
 * In-process TTL cache for sports/CricAPI responses (single VPS instance).
 */
class MemoryCache {
  constructor() {
    this._store = new Map();
  }

  get(key) {
    const entry = this._store.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this._store.delete(key);
      return null;
    }
    return entry.value;
  }

  set(key, value, ttlMs) {
    this._store.set(key, {
      value,
      expiresAt: Date.now() + Math.max(1000, ttlMs),
    });
  }

  del(key) {
    this._store.delete(key);
  }
}

module.exports = new MemoryCache();
