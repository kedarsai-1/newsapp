const { createClient } = require('redis');

class CacheService {
  constructor() {
    this._store = new Map();
    this.redisClient = null;
    this.isRedisConnected = false;
  }

  async init() {
    const redisUrl = process.env.REDIS_URL || process.env.REDIS_HOST;
    if (!redisUrl) {
      console.log('[cache] No REDIS_URL/REDIS_HOST configured. Using in-process memory cache.');
      return;
    }

    try {
      const url = redisUrl.includes('://') ? redisUrl : `redis://${redisUrl}`;
      this.redisClient = createClient({ url });
      this.redisClient.on('error', (err) => {
        console.error('[cache] Redis error:', err.message);
        this.isRedisConnected = false;
      });
      await this.redisClient.connect();
      this.isRedisConnected = true;
      console.log('[cache] Connected to Redis successfully');
    } catch (err) {
      console.error('[cache] Redis connection failed. Using in-process memory cache fallback:', err.message);
      this.redisClient = null;
      this.isRedisConnected = false;
    }
  }

  async get(key) {
    if (this.isRedisConnected && this.redisClient) {
      try {
        const data = await this.redisClient.get(key);
        if (!data) return null;
        return JSON.parse(data);
      } catch (err) {
        console.warn('[cache] Redis GET error, falling back to memory store:', err.message);
      }
    }
    const entry = this._store.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this._store.delete(key);
      return null;
    }
    return entry.value;
  }

  async set(key, value, ttlMs) {
    if (this.isRedisConnected && this.redisClient) {
      try {
        const sec = Math.max(1, Math.round(ttlMs / 1000));
        await this.redisClient.set(key, JSON.stringify(value), { EX: sec });
        return;
      } catch (err) {
        console.warn('[cache] Redis SET error, falling back to memory store:', err.message);
      }
    }
    this._store.set(key, {
      value,
      expiresAt: Date.now() + Math.max(1000, ttlMs),
    });
  }

  async del(key) {
    if (this.isRedisConnected && this.redisClient) {
      try {
        await this.redisClient.del(key);
        return;
      } catch (err) {
        console.warn('[cache] Redis DEL error, falling back to memory store:', err.message);
      }
    }
    this._store.delete(key);
  }

  async deleteByPrefix(prefix) {
    if (!prefix) return 0;
    if (this.isRedisConnected && this.redisClient) {
      try {
        let cursor = 0;
        let count = 0;
        do {
          const reply = await this.redisClient.scan(cursor, { MATCH: `${prefix}*`, COUNT: 100 });
          cursor = reply.cursor;
          const keys = reply.keys;
          if (keys && keys.length) {
            await this.redisClient.del(keys);
            count += keys.length;
          }
        } while (cursor !== 0 && cursor !== '0');
        return count;
      } catch (err) {
        console.warn('[cache] Redis SCAN/DEL error, falling back to memory store:', err.message);
      }
    }
    let n = 0;
    for (const key of [...this._store.keys()]) {
      if (key.startsWith(prefix)) {
        this._store.delete(key);
        n += 1;
      }
    }
    return n;
  }

  async clear() {
    if (this.isRedisConnected && this.redisClient) {
      try {
        await this.redisClient.flushDb();
        return;
      } catch (err) {
        console.warn('[cache] Redis FLUSHDB error, falling back to memory store:', err.message);
      }
    }
    this._store.clear();
  }
}

module.exports = new CacheService();
