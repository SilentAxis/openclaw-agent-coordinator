#!/usr/bin/env bash
# =============================================================================
# OpenClaw Agent Co-ordinator — Integration Test Runner
# =============================================================================
# Prerequisites: OpenClaw running, all 4 agent sessions active
# Usage: ./tests/run-integration-tests.sh [--test 1|2|3|4|all]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$RESULTS_DIR/$(date +%Y-%m-%d-%H%M%S).log"
ENV_FILE="${ENV_FILE:-$HOME/.openclaw/openclaw-vault/.env}"
RUN_TEST="${1:-all}"

mkdir -p "$RESULTS_DIR"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

log()     { echo -e "$*" | tee -a "$LOG_FILE"; }
info()    { log "${BLUE}[INFO]${NC}  $*"; }
pass()    { log "${GREEN}[PASS]${NC}  $*"; ((PASS++)); }
fail()    { log "${RED}[FAIL]${NC}  $*"; ((FAIL++)); }
skip()    { log "${YELLOW}[SKIP]${NC}  $*"; ((SKIP++)); }

# Load env
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

# ── Helpers ───────────────────────────────────────────────────────────────────
check_session() {
  local session_key="$1"
  if openclaw sessions --all-agents 2>/dev/null | grep -q "$session_key"; then
    return 0
  fi
  return 1
}

send_to_coordinator() {
  local message="$1"
  openclaw agent \
    --agent "coordinator" \
    --session-id "coordinator-agent" \
    --message "$message" \
    --timeout 120 2>/dev/null
}

# ── Prerequisites ─────────────────────────────────────────────────────────────
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "  OpenClaw Agent Co-ordinator — Integration Tests"
log "  $(date)"
log "  Log: $LOG_FILE"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Checking prerequisites..."

if ! command -v openclaw &>/dev/null; then
  fail "OpenClaw not found in PATH"
  exit 1
fi

SESSIONS=("session:coordinator-agent" "session:python-dev-agent" "session:docker-infra-agent" "session:creative-director-agent")
ALL_UP=true
for s in "${SESSIONS[@]}"; do
  if check_session "$s"; then
    info "  ✓ $s"
  else
    fail "  ✗ $s not found — run setup.sh and start openclaw first"
    ALL_UP=false
  fi
done

if [[ "$ALL_UP" == "false" ]]; then
  log ""
  log "One or more sessions missing. Aborting."
  exit 1
fi

# ── Test 1: Basic delegation round-trip ───────────────────────────────────────
run_test_1() {
  info "TEST 1: Basic delegation round-trip (Mike → R. Daneel → R. Sammy → Mike)"

  local result
  result=$(send_to_coordinator \
    "Task: Write a Python script that prints 'Hello from R. Sammy' and the current timestamp. Save to /tmp/test_rsami.py and run it. Return the output." \
    2>&1) || true

  if echo "$result" | grep -qi "hello from r. sammy"; then
    pass "Test 1: R. Sammy returned expected output"
  else
    fail "Test 1: Expected output not found in result"
    log "  Got: $result"
  fi

  if [[ -f "/tmp/test_rsami.py" ]]; then
    pass "Test 1: /tmp/test_rsami.py exists"
  else
    fail "Test 1: /tmp/test_rsami.py not created"
  fi
}

# ── Test 2: Timeout detection ─────────────────────────────────────────────────
run_test_2() {
  info "TEST 2: Timeout detection (NOTE: this test takes ~5 minutes)"
  skip "Test 2: Timeout test requires live 5-minute wait — run manually"
  log "  Manual steps in integration-test-plan.md"
}

# ── Test 3: Parallel dispatch ─────────────────────────────────────────────────
run_test_3() {
  info "TEST 3: Multi-agent parallel dispatch (R. Sammy + R. Giskard)"

  local result
  result=$(send_to_coordinator \
    "Two parallel tasks: (A) List all running Python processes on this machine. (B) List all running Docker containers. Run both in parallel and report combined results." \
    2>&1) || true

  if echo "$result" | grep -qi "python\|process"; then
    pass "Test 3: Python process output present"
  else
    fail "Test 3: Python process info missing from result"
  fi

  if echo "$result" | grep -qi "docker\|container"; then
    pass "Test 3: Docker container output present"
  else
    fail "Test 3: Docker container info missing from result"
  fi
}

# ── Test 4: Creative Director round-trip ──────────────────────────────────────
run_test_4() {
  info "TEST 4: Creative Director round-trip"

  local result
  result=$(send_to_coordinator \
    "Task: Write a two-sentence announcement for the OpenClaw Agent Co-ordinator project launch. Audience: technical blog readers. Must be publish-ready." \
    2>&1) || true

  if [[ ${#result} -gt 100 ]]; then
    pass "Test 4: R. Andrew returned substantive content"
    log "  Preview: ${result:0:200}..."
  else
    fail "Test 4: Response too short or empty"
    log "  Got: $result"
  fi
}

# ── Run ───────────────────────────────────────────────────────────────────────
case "$RUN_TEST" in
  1|--test\ 1) run_test_1 ;;
  2|--test\ 2) run_test_2 ;;
  3|--test\ 3) run_test_3 ;;
  4|--test\ 4) run_test_4 ;;
  all|*)
    run_test_1
    run_test_2
    run_test_3
    run_test_4
    ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "  Results: ${GREEN}${PASS} passed${NC} | ${RED}${FAIL} failed${NC} | ${YELLOW}${SKIP} skipped${NC}"
log "  Full log: $LOG_FILE"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
