#!/usr/bin/env bash
# =============================================================================
# OpenClaw Agent Co-ordinator — Setup Script
# =============================================================================
# Usage:
#   ./setup.sh [--agent-root /opt/OpenclawAgent] [--config-path /path/to/openclaw.json]
#
# What this does:
#   1. Validates prerequisites (openclaw installed, API keys present)
#   2. Creates required directories for all agents
#   3. Copies workspace identity files into place
#   4. Registers persistent named sessions with OpenClaw
#   5. Validates the openclaw.json config
#   6. Prints deployment summary
#
# Safe to re-run (idempotent).
# =============================================================================

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ROOT="${AGENT_ROOT:-$SCRIPT_DIR}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG_PATH:-$AGENT_ROOT/openclaw.json}"
ENV_FILE="${ENV_FILE:-$HOME/.openclaw/openclaw-vault/.env}"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent-root)  AGENT_ROOT="$2"; shift 2 ;;
    --config-path) OPENCLAW_CONFIG="$2"; shift 2 ;;
    --env-file)    ENV_FILE="$2"; shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenClaw Agent Co-ordinator — Setup"
echo "  Agent root:  $AGENT_ROOT"
echo "  Config:      $OPENCLAW_CONFIG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Prerequisites ─────────────────────────────────────────────────────
info "Step 1: Checking prerequisites..."

if ! command -v openclaw &>/dev/null; then
  error "OpenClaw is not installed or not in PATH. Install it first: https://docs.openclaw.ai"
fi
success "OpenClaw found: $(openclaw --version 2>/dev/null || echo 'installed')"

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
  success "Loaded .env from $ENV_FILE"
else
  warn ".env not found at $ENV_FILE — ensure API keys are set in environment"
fi

# Check required API key
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  error "ANTHROPIC_API_KEY is not set. Add it to your .env or environment."
fi
success "ANTHROPIC_API_KEY present"

# ── Step 2: Create directories ────────────────────────────────────────────────
info "Step 2: Creating agent directories..."

AGENTS=("coordinator" "python-dev" "docker-infra" "creative-director")

for agent in "${AGENTS[@]}"; do
  for dir in "workspace/memory" "agent" "sessions"; do
    mkdir -p "$AGENT_ROOT/$agent/$dir"
  done
  success "  $agent/ directories ready"
done

# ── Step 3: Verify workspace identity files ───────────────────────────────────
info "Step 3: Verifying workspace identity files..."

FILES=("IDENTITY.md" "SOUL.md" "AGENTS.md")

for agent in "${AGENTS[@]}"; do
  for file in "${FILES[@]}"; do
    src="$AGENT_ROOT/$agent/workspace/$file"
    if [[ ! -f "$src" ]]; then
      error "Missing: $src — re-clone the repo or check your agent-root path"
    fi
  done
  success "  $agent workspace files OK"
done

# ── Step 4: Register persistent sessions ──────────────────────────────────────
info "Step 4: Registering persistent named sessions..."

SESSION_CONFIG="$AGENT_ROOT/config/cron-sessions.json"
if [[ ! -f "$SESSION_CONFIG" ]]; then
  error "Missing session config: $SESSION_CONFIG"
fi

# Use openclaw sessions register if available, otherwise note for manual step
if openclaw sessions register --help &>/dev/null 2>&1; then
  AGENT_ROOT="$AGENT_ROOT" openclaw sessions register --config "$SESSION_CONFIG"
  success "Persistent sessions registered"
else
  warn "openclaw sessions register not available — sessions will be created on first use"
  warn "Manual alternative: start each agent session once to initialise it"
fi

# ── Step 5: Validate openclaw.json ─────────────────────────────────────────────
info "Step 5: Validating openclaw.json..."

if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  error "openclaw.json not found at $OPENCLAW_CONFIG"
fi

if command -v jq &>/dev/null; then
  jq empty "$OPENCLAW_CONFIG" && success "openclaw.json is valid JSON"
else
  warn "jq not installed — skipping JSON validation"
fi

# ── Step 6: Summary ───────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Setup complete!${NC}"
echo ""
echo "  Agents deployed:"
echo -e "    🧠 R. Daneel Olivaw    — Co-ordinator         (session:coordinator-agent)"
echo -e "    🐍 R. Sammy            — Python Developer     (session:python-dev-agent)"
echo -e "    🐳 R. Giskard Reventlov — Docker/Infra        (session:docker-infra-agent)"
echo -e "    🎨 R. Andrew Martin    — Creative Director    (session:creative-director-agent)"
echo ""
echo "  To start OpenClaw with this fleet:"
echo "    OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG openclaw gateway start"
echo ""
echo "  To verify agents are reachable:"
echo "    openclaw sessions list"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
