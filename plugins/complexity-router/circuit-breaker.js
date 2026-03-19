/**
 * complexity-router: circuit-breaker.js
 * In-memory circuit breaker for model/provider availability.
 * Promotes to the next candidate when a provider is failing.
 */

// Models tracked by the circuit breaker
export const TRACKED_MODELS = new Set([
  'anthropic/claude-opus-4-6',
  'anthropic/claude-haiku-4-5',
  'anthropic/claude-sonnet-4-6',
  'openai-codex/gpt-5.4-mini',
  'openai-codex/gpt-5.3-codex',
  'openai-codex/gpt-5.4',
]);

export class CircuitBreaker {
  /**
   * @param {{ threshold?: number, windowMs?: number, resetMs?: number }} opts
   */
  constructor({ threshold = 3, windowMs = 300_000, resetMs = 180_000 } = {}) {
    this.threshold = threshold;
    this.windowMs = windowMs;
    this.resetMs = resetMs;
    /** @type {Map<string, { failures: number[], openUntil: number, trips: number }>} */
    this._state = new Map();
  }

  _getState(model) {
    if (!this._state.has(model)) {
      this._state.set(model, { failures: [], openUntil: 0, trips: 0 });
    }
    return this._state.get(model);
  }

  /**
   * Record a failure for a model. Opens circuit if threshold exceeded.
   */
  recordFailure(model) {
    const now = Date.now();
    const state = this._getState(model);

    if (state.openUntil > 0 && now > state.openUntil + (this.resetMs * 2)) {
      state.trips = 0;
    }

    state.failures = state.failures.filter(t => now - t < this.windowMs);
    state.failures.push(now);

    if (state.failures.length >= this.threshold || state.trips > 0) {
      const backoffMultiplier = Math.pow(2, state.trips);
      const backoffTime = this.resetMs * backoffMultiplier;

      state.openUntil = now + backoffTime;
      state.trips += 1;
      state.failures = [];
    }
  }

  /**
   * Record a success — resets failure count and trips for model.
   */
  recordSuccess(model) {
    const state = this._getState(model);
    state.failures = [];
    state.openUntil = 0;
    state.trips = 0;
  }

  /**
   * Returns true if the circuit is open (model should be skipped).
   */
  isOpen(model) {
    if (!TRACKED_MODELS.has(model)) return false;
    const state = this._getState(model);
    return Date.now() < state.openUntil;
  }

  /**
   * Get full circuit state (for logging/testing).
   */
  getState() {
    const result = {};
    for (const [model, state] of this._state.entries()) {
      result[model] = {
        failures: state.failures.length,
        openUntil: state.openUntil,
        isOpen: Date.now() < state.openUntil,
      };
    }
    return result;
  }

  /**
   * Reset all state (for testing).
   */
  reset() {
    this._state.clear();
  }
}
