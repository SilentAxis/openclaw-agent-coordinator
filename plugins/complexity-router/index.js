/**
 * complexity-router: index.js
 * OpenClaw plugin — routes messages to optimal model based on complexity scoring.
 *
 * Hooks: before_model_resolve, llm_output
 * Works globally across all channels (BB, Telegram, webchat, etc.)
 */

import { scorePrompt, scoreTier, TIER_MODELS, TIER_FALLBACKS } from './scorer.js';
import { CircuitBreaker, TRACKED_MODELS } from './circuit-breaker.js';
import { SessionTierCache } from './session-cache.js';

// Short prompt threshold for follow-up detection (tokens)
const FOLLOWUP_TOKEN_THRESHOLD = 50;

function resolveConfig(pluginConfig) {
  const cfg = pluginConfig || {};
  return {
    enabled: cfg.enabled !== false,
    logDecisions: cfg.logDecisions === true,
    bypassTriggers: cfg.bypassTriggers || ['heartbeat', 'cron'],
    channelOverrides: cfg.channelOverrides || {},
    circuitBreakerThreshold: cfg.circuitBreakerThreshold || 3,
    circuitBreakerWindowMs: cfg.circuitBreakerWindowMs || 300_000,
    circuitBreakerResetMs: cfg.circuitBreakerResetMs || 180_000,
  };
}

const plugin = {
  activate(api) {
    const config = resolveConfig(api.pluginConfig);
    const breaker = new CircuitBreaker({
      threshold: config.circuitBreakerThreshold,
      windowMs: config.circuitBreakerWindowMs,
      resetMs: config.circuitBreakerResetMs,
    });
    const sessionCache = new SessionTierCache({ ttlMs: 30 * 60 * 1000 });

    api.on('before_model_resolve', (event, ctx) => {
      if (!config.enabled) return;

      const { prompt } = event;
      const { channelId, trigger, sessionKey } = ctx;

      if (!prompt || prompt.trim().length < 3) return;
      if (config.bypassTriggers.includes(trigger)) return;

      const score = scorePrompt(prompt);
      let tier = scoreTier(score);
      const tokens = Math.ceil(prompt.length / 4);
      const isShortFollowup = tokens < FOLLOWUP_TOKEN_THRESHOLD;

      if (isShortFollowup && sessionKey) {
        const cachedTier = sessionCache.get(sessionKey);
        if (cachedTier !== null && cachedTier > tier) {
          tier = Math.min(cachedTier, tier + 1);
        }
      }

      const channelOverride = config.channelOverrides[channelId];
      if (channelOverride?.maxTier && tier > channelOverride.maxTier) {
        tier = channelOverride.maxTier;
      }

      const fallbackChain = TIER_FALLBACKS[tier] || [TIER_MODELS[tier]];
      const model = fallbackChain.find(m => !breaker.isOpen(m));
      if (!model) {
        if (config.logDecisions) {
          api.logger.warn(`[complexity-router] all providers in cooldown for tier ${tier}, disabling override`);
        }
        return;
      }
      const finalTier = tier;

      if (sessionKey) {
        sessionCache.set(sessionKey, finalTier);
      }

      if (config.logDecisions) {
        api.logger.info(
          `[complexity-router] channel=${channelId || 'unknown'} trigger=${trigger || 'user'} ` +
          `score=${score} tier=${finalTier} model=${model} session=${sessionKey || 'none'}`
        );
      }

      const slashIdx = model.indexOf('/');
      if (slashIdx > 0) {
        return {
          providerOverride: model.slice(0, slashIdx),
          modelOverride: model.slice(slashIdx + 1),
        };
      }
      return { modelOverride: model };
    });

    api.on('llm_output', event => {
      const { provider, model } = event;
      const fullModel = `${provider}/${model}`;

      if (TRACKED_MODELS.has(fullModel)) {
        if (!event.usage || (!event.usage.output && !event.usage.total)) {
          breaker.recordFailure(fullModel);
        } else {
          breaker.recordSuccess(fullModel);
        }
      }
    });
  },
};

export default plugin;
