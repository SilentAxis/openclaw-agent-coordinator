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

PREREQ_FAIL=false

# OpenClaw
if ! command -v openclaw &>/dev/null; then
  error "OpenClaw is not installed or not in PATH. See: https://docs.openclaw.ai"
fi
success "openclaw: $(openclaw --version 2>/dev/null || echo 'installed')"

# git
if ! command -v git &>/dev/null; then
  warn "git not found — install with: apt install git / brew install git"
  PREREQ_FAIL=true
else
  success "git: $(git --version)"
fi

# uv / uvx (required for jCodeMunch + jDocMunch MCP tools)
if ! command -v uvx &>/dev/null; then
  warn "uvx not found — install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
  PREREQ_FAIL=true
else
  success "uvx: $(uvx --version 2>/dev/null || echo 'installed')"
fi

# python3
if ! command -v python3 &>/dev/null; then
  warn "python3 not found — install with: apt install python3"
  PREREQ_FAIL=true
else
  success "python3: $(python3 --version)"
fi

# jq (optional but recommended)
if ! command -v jq &>/dev/null; then
  warn "jq not found — JSON validation will be skipped. Install: apt install jq"
else
  success "jq: $(jq --version)"
fi

# curl
if ! command -v curl &>/dev/null; then
  warn "curl not found — install with: apt install curl"
  PREREQ_FAIL=true
else
  success "curl: present"
fi

# docker (optional — only needed for docker-infra agent)
if ! command -v docker &>/dev/null; then
  warn "docker not found — R. Giskard (docker-infra agent) will be limited. See: https://docs.docker.com/engine/install/"
else
  success "docker: $(docker --version)"
fi

# MCP tools via uvx
info "Checking MCP tools..."
if command -v uvx &>/dev/null; then
  if uvx jcodemunch-mcp --help &>/dev/null 2>&1; then
    success "jcodemunch-mcp: available"
  else
    warn "jcodemunch-mcp: not cached — will be fetched on first use by OpenClaw"
  fi
  if uvx jdocmunch-mcp --help &>/dev/null 2>&1; then
    success "jdocmunch-mcp: available"
  else
    warn "jdocmunch-mcp: not cached — will be fetched on first use by OpenClaw"
  fi
fi

[[ "$PREREQ_FAIL" == "true" ]] && error "One or more required prerequisites missing. Fix above warnings and re-run."

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
  success "Loaded .env from $ENV_FILE"
elif [[ -f "$AGENT_ROOT/.env" ]]; then
  set -a
  source "$AGENT_ROOT/.env"
  set +a
  success "Loaded .env from $AGENT_ROOT/.env"
else
  warn ".env not found — ensure API keys are set in environment"
  warn "Copy $AGENT_ROOT/.env.example to $AGENT_ROOT/.env and fill in your keys"
fi

# Check Anthropic auth — API key OR OAuth (Claude subscription via OpenClaw)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  success "ANTHROPIC_API_KEY present"
else
  # Check for OpenClaw OAuth auth profile (Claude subscription)
  OAUTH_PROFILE=$(find "$HOME/.openclaw" -path "*/auth-profiles*" -name "*.json" 2>/dev/null | head -1)
  if [[ -n "$OAUTH_PROFILE" ]]; then
    success "Anthropic auth: OpenClaw OAuth profile found (Claude subscription)"
  else
    warn "ANTHROPIC_API_KEY not set and no OAuth profile found."
    warn "If using Claude via subscription, run 'openclaw onboard' on this machine first."
    warn "If using API key, add ANTHROPIC_API_KEY to $AGENT_ROOT/.env"
  fi
fi

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

# Persistent named sessions are created on first use via sessionTarget in cron jobs.
# No explicit registration step needed — OpenClaw creates them automatically.
success "Session config verified: $SESSION_CONFIG"
info "  Sessions will be created on first use (sessionTarget: session:*-agent)"

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
