# INSTALL.md — OpenClaw Agent Co-ordinator

Complete installation guide for deploying the agent fleet on a fresh machine.

---

## Step 1 — Install OpenClaw

OpenClaw is the runtime that powers all agents. Install it first.

### macOS / Linux
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

### Windows (PowerShell)
```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

**Node.js requirement:** Node 24 recommended, Node 22 LTS (`22.16+`) minimum.
Check yours: `node --version`

### Run onboarding
```bash
openclaw onboard --install-daemon
```
This configures auth, gateway settings, and installs OpenClaw as a system service.

### Verify
```bash
openclaw gateway status
```

> 📖 Full docs: https://docs.openclaw.ai/start/getting-started

---

## Step 2 — Install uv (Python tool runner)

Required for jCodeMunch and jDocMunch MCP tools.

### macOS / Linux
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env   # or restart your shell
```

### Windows
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Verify: `uvx --version`

---

## Step 3 — Install system dependencies

### Debian / Ubuntu
```bash
apt install -y git jq curl python3
```

### macOS
```bash
brew install git jq curl python3
```

### Docker (optional — required for R. Giskard / docker-infra agent)
```bash
# Debian/Ubuntu
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin

# macOS
# Install Docker Desktop: https://docs.docker.com/desktop/mac/install/
```

---

## Step 4 — Clone the repo

```bash
git clone https://github.com/SilentAxis/openclaw-agent-coordinator /opt/OpenclawAgent
cd /opt/OpenclawAgent
```

> You can clone to any directory. Set `AGENT_ROOT` in your env or pass `--agent-root` to `setup.sh` if you use a different path.

---

## Step 5 — Configure API keys

```bash
cp .env.example .env
```

Edit `.env` and fill in your keys:

```bash
# Required
ANTHROPIC_API_KEY=sk-ant-...

# Optional but recommended
GOOGLE_API_KEY=...        # enables AI summaries in jCodeMunch/jDocMunch
OPENAI_API_KEY=...        # fallback model provider
GITHUB_TOKEN=...          # if agents push code to GitHub
```

---

## Step 6 — Pre-cache MCP tools (recommended)

```bash
uvx jcodemunch-mcp --help
uvx jdocmunch-mcp --help
```

Both will be fetched automatically on first use if you skip this — but pre-caching avoids a delay on first agent run.

---

## Step 7 — Run setup

```bash
./setup.sh
```

This will:
- Verify all prerequisites
- Create agent directories
- Verify identity files (SOUL.md, IDENTITY.md, AGENTS.md)
- Register persistent sessions with OpenClaw
- Validate `openclaw.json`

Safe to re-run at any time.

---

## Step 8 — Start OpenClaw with the agent fleet

```bash
OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json openclaw gateway start
```

To make this permanent, add to your shell profile or systemd service:
```bash
export OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json
```

---

## Step 9 — Verify

```bash
# Check gateway is running
openclaw gateway status

# List active sessions
openclaw sessions list

# Open Control UI
openclaw dashboard
```

You should see 4 agent sessions:
- `session:coordinator-agent` — R. Daneel 🧠
- `session:python-dev-agent` — R. Sammy 🐍
- `session:docker-infra-agent` — R. Giskard 🐳
- `session:creative-director-agent` — R. Andrew 🎨

---

## Step 10 — Run integration tests

```bash
./tests/run-integration-tests.sh
```

All tests passing = fleet is operational.

---

## OpenClaw install locations

| Path | Purpose |
|------|---------|
| `~/.openclaw/` | OpenClaw home — credentials, state, default config |
| `~/.openclaw/openclaw.json` | Default config (do NOT edit for this project) |
| `/opt/OpenclawAgent/openclaw.json` | **This project's config** — use `OPENCLAW_CONFIG_PATH` |
| `/opt/OpenclawAgent/*/workspace/` | Agent workspace files (SOUL.md, memory, etc.) |
| `/opt/OpenclawAgent/*/sessions/` | Persistent session state |

> ⚠️ This project runs alongside your existing OpenClaw install without touching it. The `OPENCLAW_CONFIG_PATH` env var points OpenClaw at the fleet config instead of the default.

---

## Troubleshooting

**`openclaw: command not found`**
→ Re-run the install script or add `~/.openclaw/bin` to your `PATH`.

**`ANTHROPIC_API_KEY is not set`**
→ Check your `.env` file and make sure `setup.sh` is loading it.

**`uvx: command not found`**
→ Install `uv`: `curl -LsSf https://astral.sh/uv/install.sh | sh` then restart shell.

**Sessions not appearing after `./setup.sh`**
→ Make sure OpenClaw gateway is running first: `openclaw gateway status`

**jCodeMunch/jDocMunch errors**
→ Run `uvx jcodemunch-mcp --help` to pre-cache, then restart the gateway.
