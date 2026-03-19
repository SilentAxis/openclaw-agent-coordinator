/**
 * complexity-router: scorer.test.js
 * Run with: node scorer.test.js
 */

import assert from 'node:assert/strict';
import { scorePrompt, scoreTier, tierModel, TIER_MODELS } from './scorer.js';
import { CircuitBreaker, TRACKED_MODELS } from './circuit-breaker.js';
import { SessionTierCache } from './session-cache.js';

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

console.log('\nScorer - prompt -> tier routing');

test('Tier 1: "what time is it?"', () => {
  assert.equal(scoreTier(scorePrompt('what time is it?')), 1);
});

test('Tier 1: "remind me to call mom at 5pm"', () => {
  assert.equal(scoreTier(scorePrompt('remind me to call mom at 5pm')), 1);
});

test('Tier 1: "ok" (trivial continuation)', () => {
  assert.equal(scoreTier(scorePrompt('ok')), 1);
});

test('Tier 2: "explain how HTTPS works"', () => {
  const tier = scoreTier(scorePrompt('explain how HTTPS works'));
  assert.ok(tier >= 2, `expected tier >= 2, got ${tier}`);
});

test('Tier 2: "write a bash script to backup docker volumes"', () => {
  const tier = scoreTier(scorePrompt('write a bash script to backup docker volumes'));
  assert.ok(tier >= 2, `expected tier >= 2, got ${tier}`);
});

test('Tier 3: "compare kubernetes vs docker swarm for a small homelab"', () => {
  const tier = scoreTier(scorePrompt('compare kubernetes vs docker swarm for a small homelab'));
  assert.ok(tier >= 3, `expected tier >= 3, got ${tier}`);
});

test('Tier 3: "design a webhook security system with HMAC signing"', () => {
  const tier = scoreTier(scorePrompt('design a webhook security system with HMAC signing'));
  assert.ok(tier >= 3, `expected tier >= 3, got ${tier}`);
});

test('Tier 4: "build a full multi-agent orchestration system with fallback routing"', () => {
  const tier = scoreTier(scorePrompt('build a full multi-agent orchestration system with fallback routing'));
  assert.equal(tier, 4);
});

test('Tier 4: "help me plan, design, and implement a new OpenClaw plugin with tests"', () => {
  const tier = scoreTier(scorePrompt('help me plan, design, and implement a new OpenClaw plugin with tests'));
  assert.equal(tier, 4);
});

test('Tier 4: long technical proposal', () => {
  const tier = scoreTier(scorePrompt(
    'write a detailed technical proposal comparing 5 different approaches to distributed caching with trade-off analysis and recommendation'
  ));
  assert.equal(tier, 4);
});

console.log('\nScorer - edge cases');

test('Empty prompt -> score 0', () => {
  assert.equal(scorePrompt(''), 0);
});

test('Very short prompt -> score 0', () => {
  assert.equal(scorePrompt('hi'), 0);
});

test('Score is clamped 0-100', () => {
  const score = scorePrompt('a'.repeat(10000));
  assert.ok(score >= 0 && score <= 100, `score out of range: ${score}`);
});

test('TIER_MODELS has 5 entries (null + 4 tiers)', () => {
  assert.equal(TIER_MODELS.length, 5);
  assert.equal(TIER_MODELS[0], null);
});

test('tierModel(1) returns gpt-5.4-mini', () => {
  assert.ok(tierModel(1).includes('gpt-5.4-mini'));
});

test('tierModel(4) returns gpt-5.4', () => {
  assert.ok(tierModel(4).includes('gpt-5.4'));
});

console.log('\nCircuit Breaker');

test('Circuit starts closed', () => {
  const cb = new CircuitBreaker();
  assert.equal(cb.isOpen('openai-codex/gpt-5.4-mini'), false);
});

test('Circuit opens after threshold failures', () => {
  const cb = new CircuitBreaker({ threshold: 3, windowMs: 60000, resetMs: 600000 });
  const model = 'openai-codex/gpt-5.4-mini';
  cb.recordFailure(model);
  cb.recordFailure(model);
  assert.equal(cb.isOpen(model), false, 'should still be closed after 2 failures');
  cb.recordFailure(model);
  assert.equal(cb.isOpen(model), true, 'should be open after 3 failures');
});

test('Circuit closed for untracked models', () => {
  const cb = new CircuitBreaker({ threshold: 1 });
  const model = 'custom-192-168-99-96-11434/llama3.1:8b';
  cb.recordFailure(model);
  assert.equal(cb.isOpen(model), false, 'untracked models should never open');
});

test('Success resets failure count', () => {
  const cb = new CircuitBreaker({ threshold: 3, windowMs: 60000, resetMs: 600000 });
  const model = 'openai-codex/gpt-5.4-mini';
  cb.recordFailure(model);
  cb.recordFailure(model);
  cb.recordSuccess(model);
  cb.recordFailure(model);
  assert.equal(cb.isOpen(model), false, 'should be closed after success reset');
});

test('TRACKED_MODELS set contains the OpenAI/Anthropic tiers', () => {
  assert.ok(TRACKED_MODELS.has('openai-codex/gpt-5.4-mini'));
  assert.ok(TRACKED_MODELS.has('openai-codex/gpt-5.3-codex'));
  assert.ok(TRACKED_MODELS.has('openai-codex/gpt-5.4'));
  assert.ok(TRACKED_MODELS.has('anthropic/claude-opus-4-6'));
});

console.log('\nSession Cache');

test('Returns null for unknown session', () => {
  const cache = new SessionTierCache();
  assert.equal(cache.get('nonexistent'), null);
});

test('Stores and retrieves tier', () => {
  const cache = new SessionTierCache();
  cache.set('session-1', 3);
  assert.equal(cache.get('session-1'), 3);
});

test('Expires after TTL', async () => {
  const cache = new SessionTierCache({ ttlMs: 10 });
  cache.set('session-2', 2);
  await new Promise(r => setTimeout(r, 20));
  assert.equal(cache.get('session-2'), null, 'entry should be expired');
});

test('Clear removes entry', () => {
  const cache = new SessionTierCache();
  cache.set('session-3', 4);
  cache.clear('session-3');
  assert.equal(cache.get('session-3'), null);
});

test('Null sessionKey is a no-op', () => {
  const cache = new SessionTierCache();
  cache.set(null, 3);
  assert.equal(cache.get(null), null);
});

console.log(`\n${'-'.repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.error('\nTests failed');
  process.exit(1);
} else {
  console.log('\nAll tests passed');
}
