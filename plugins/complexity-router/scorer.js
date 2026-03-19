/**
 * complexity-router: scorer.js
 * Pure synchronous scoring logic. Zero dependencies, zero latency.
 */

export const TIER_MODELS = [
  null, // index 0 unused
  'openai-codex/gpt-5.4-mini',   // Tier 1: simple/trivial
  'openai-codex/gpt-5.4-mini',   // Tier 2: medium
  'openai-codex/gpt-5.3-codex',  // Tier 3: reasoning
  'openai-codex/gpt-5.4',        // Tier 4: complex
];

export const TIER_NAMES = [null, 'simple', 'medium', 'reasoning', 'complex'];

/**
 * Provider fallback chains per tier.
 * When the primary model for a tier is circuit-broken, try the next
 * provider in order — never the same provider twice in a row.
 */
export const TIER_FALLBACKS = {
  1: [
    'openai-codex/gpt-5.4-mini',
    'openai-codex/gpt-5.3-codex',
    'openai-codex/gpt-5.4',
    'anthropic/claude-haiku-4-5',
    'anthropic/claude-sonnet-4-6',
  ],
  2: [
    'openai-codex/gpt-5.4-mini',
    'openai-codex/gpt-5.3-codex',
    'openai-codex/gpt-5.4',
    'anthropic/claude-haiku-4-5',
    'anthropic/claude-sonnet-4-6',
  ],
  3: [
    'openai-codex/gpt-5.3-codex',
    'openai-codex/gpt-5.4',
    'anthropic/claude-sonnet-4-6',
    'anthropic/claude-haiku-4-5',
  ],
  4: [
    'openai-codex/gpt-5.4',
    'openai-codex/gpt-5.3-codex',
    'anthropic/claude-sonnet-4-6',
    'anthropic/claude-opus-4-6',
  ],
};

/**
 * Score a prompt for complexity (0-100).
 * Deterministic, auditable, zero-latency.
 */
export function scorePrompt(prompt) {
  if (!prompt || prompt.trim().length < 3) return 0;

  let score = 0;
  const text = prompt.toLowerCase().trim();
  const tokens = Math.ceil(prompt.length / 4);

  score += Math.min(25, tokens / 8);

  if (/```|`[^`\n]+`/.test(prompt)) score += 20;

  const questionCount = (prompt.match(/\?/g) || []).length;
  if (questionCount > 1) score += 10;

  const reasoningKw = ['why', 'how', 'analyze', 'analyse', 'explain', 'compare', 'evaluate', 'assess', 'review', 'difference between', 'vs ', 'versus'];
  const hasReasoning = reasoningKw.some(kw => text.includes(kw));
  if (hasReasoning) score += 15;

  const domainKw = ['security', 'legal', 'medical', 'architecture', 'infrastructure', 'database', 'algorithm', 'authentication', 'encryption', 'compliance', 'gdpr', 'hipaa', 'hmac', 'orchestration', 'kubernetes', 'docker', 'bash', 'script', 'https', 'http', 'ssl', 'tls', 'webhook', 'api', 'plugin', 'system', 'caching', 'cache', 'distributed', 'multi-agent'];
  const hasDomain = domainKw.some(kw => text.includes(kw));
  if (hasDomain) score += 15;

  const planningKw = ['plan', 'strategy', 'proposal', 'specification', 'comprehensive', 'detailed', 'multi-step', 'multiple', 'trade-off', 'tradeoff', 'implement', 'design', 'build', 'develop', 'create', 'write', 'write a', 'write the'];
  const hasPlanning = planningKw.some(kw => text.includes(kw));
  if (hasPlanning) score += 15;

  const complexSignals = [
    reasoningKw.some(kw => text.includes(kw)),
    domainKw.some(kw => text.includes(kw)),
    planningKw.some(kw => text.includes(kw)),
    questionCount > 1,
    /```|`[^`\n]+`/.test(prompt),
  ].filter(Boolean).length;
  if (complexSignals >= 2) score += 10;

  if (/\b(step \d|part \d|\d\.\s|\d\)\s)/.test(text)) score += 5;

  const trivialPhrases = ['ok', 'okay', 'thanks', 'thank you', 'yes', 'no', 'sure', 'got it', 'sounds good', 'great', 'perfect', 'nice', 'cool'];
  if (trivialPhrases.some(kw => text === kw || text === kw + '.' || text === kw + '!')) score -= 15;

  return Math.max(0, Math.min(100, Math.round(score)));
}

/**
 * Map a score (0-100) to a tier (1-4).
 * Thresholds calibrated to actual keyword-based score distribution.
 */
export function scoreTier(score) {
  if (score <= 15) return 1;
  if (score <= 28) return 2;
  if (score <= 38) return 3;
  return 4;
}

/**
 * Get model string for a tier (1-4).
 */
export function tierModel(tier) {
  return TIER_MODELS[Math.max(1, Math.min(4, tier))];
}
