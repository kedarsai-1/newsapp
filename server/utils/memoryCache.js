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

  deleteByPrefix(prefix) {
    if (!prefix) return 0;
    let n = 0;
    for (const key of [...this._store.keys()]) {
      if (key.startsWith(prefix)) {
        this._store.delete(key);
        n += 1;
      }
    }
    return n;
  }

  clear() {
    this._store.clear();
  }
}

module.exports = new MemoryCache();
