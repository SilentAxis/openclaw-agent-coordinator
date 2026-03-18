# Dependencies

Everything required to deploy the OpenClaw Agent Co-ordinator fleet on a fresh machine.

---

## 1. Core Runtime

| Dependency | Purpose | Install |
|-----------|---------|---------|
| **OpenClaw** | Agent runtime, session management, MCP orchestration | See https://docs.openclaw.ai |
| **Node.js ≥ 18** | Required by OpenClaw | `nvm install 22` or distro package |
| **Git** | Clone this repo | `apt install git` / `brew install git` |

---

## 2. Python Tooling

| Dependency | Purpose | Install |
|-----------|---------|---------|
| **uv** | Fast Python package manager (runs uvx) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **uvx** | Included with uv — runs MCP tools without venv | Included when you install `uv` |
| **python3 ≥ 3.11** | Required by MCP tools | Usually pre-installed; `apt install python3` |

---

## 3. MCP Tools (via uvx — auto-fetched on first run)

| Tool | Package | Purpose |
|------|---------|---------|
| **jCodeMunch** | `jcodemunch-mcp` | Token-efficient code exploration (index + symbol search) |
| **jDocMunch** | `jdocmunch-mcp` | Token-efficient documentation search |

Both are fetched automatically by `uvx` on first use. No manual install needed.

To pre-cache them (recommended for offline/airgapped deployments):
```bash
uvx jcodemunch-mcp --help
uvx jdocmunch-mcp --help
```

---

## 4. Infrastructure Tools

| Dependency | Purpose | Required by | Install |
|-----------|---------|------------|---------|
| **Docker** | Container management | R. Giskard (docker-infra agent) | https://docs.docker.com/engine/install/ |
| **Docker Compose v2** | Service orchestration | R. Giskard | Included with Docker Desktop; `apt install docker-compose-plugin` on Linux |
| **jq** | JSON validation in setup.sh | setup.sh | `apt install jq` / `brew install jq` |
| **curl** | API calls in setup.sh | setup.sh | Pre-installed on most systems |

> Docker is only required if R. Giskard (docker-infra agent) will be active on this machine. For coordinator-only or python-dev-only deployments it can be skipped.

---

## 5. API Keys (Environment Variables)

Set in `.env` or exported before running `setup.sh`:

| Variable | Required | Purpose |
|----------|----------|---------|
| `ANTHROPIC_API_KEY` | ✅ Required | Powers all 4 agents (haiku + sonnet) |
| `OPENAI_API_KEY` | Optional | Fallback model provider |
| `GOOGLE_API_KEY` | Optional | Gemini fallback; also enables jCodeMunch/jDocMunch AI summaries |
| `GITHUB_TOKEN` | Optional | For agents that push code to GitHub |

---

## 6. Quick Install Checklist

```bash
# 1. Install OpenClaw (follow docs.openclaw.ai)

# 2. Install uv (includes uvx)
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# 3. Install jq and curl
apt install -y jq curl        # Debian/Ubuntu
# brew install jq curl        # macOS

# 4. Install Docker (if using docker-infra agent)
# https://docs.docker.com/engine/install/

# 5. Pre-cache MCP tools
uvx jcodemunch-mcp --help
uvx jdocmunch-mcp --help

# 6. Set API keys
cp .env.example .env
# Edit .env with your keys

# 7. Run setup
./setup.sh

# 8. Start OpenClaw
OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json openclaw gateway start
```

---

## 7. Tested On

| OS | Status |
|----|--------|
| Ubuntu 22.04 / 24.04 | ✅ |
| Debian 12 | ✅ (OpenClaw host) |
| macOS 14+ | 🔜 untested |
| Raspberry Pi OS (arm64) | 🔜 Phase 3 |
