/**
 * complexity-router: session-cache.js
 * Lightweight session tier cache.
 * Ensures short follow-up messages inherit the session's complexity tier.
 */

export class SessionTierCache {
  /**
   * @param {{ ttlMs?: number }} opts
   */
  constructor({ ttlMs = 30 * 60 * 1000 } = {}) {
    this.ttlMs = ttlMs;
    /** @type {Map<string, { tier: number, updatedAt: number }>} */
    this._cache = new Map();
  }

  /**
   * Get the cached tier for a session. Returns null if expired or not set.
   * @param {string} sessionKey
   * @returns {number|null}
   */
  get(sessionKey) {
    if (!sessionKey) return null;
    const entry = this._cache.get(sessionKey);
    if (!entry) return null;
    if (Date.now() - entry.updatedAt > this.ttlMs) {
      this._cache.delete(sessionKey);
      return null;
    }
    return entry.tier;
  }

  /**
   * Set the tier for a session.
   * @param {string} sessionKey
   * @param {number} tier
   */
  set(sessionKey, tier) {
    if (!sessionKey) return;
    this._cache.set(sessionKey, { tier, updatedAt: Date.now() });
  }

  /**
   * Clear a session's cache entry.
   * @param {string} sessionKey
   */
  clear(sessionKey) {
    this._cache.delete(sessionKey);
  }

  /**
   * Clear all entries (for testing).
   */
  reset() {
    this._cache.clear();
  }

  /**
   * Get cache size (for testing/debugging).
   */
  get size() {
    return this._cache.size;
  }
}
