# OpenClaw Agent Co-ordinator

A self-hosted, portable AI agent fleet built on [OpenClaw](https://openclaw.ai). Four specialised agents — named after Asimov's robots — that collaborate to handle coding, infrastructure, and creative tasks.

---

## The Fleet

| Agent | Name | Role | Model |
|-------|------|------|-------|
| 🧠 Co-ordinator | **R. Daneel Olivaw** | Receives tasks, classifies, delegates, aggregates results | sonnet |
| 🐍 Python Developer | **R. Sammy** | Scripts, automation, API integrations, data pipelines | haiku → sonnet |
| 🐳 Docker / Infra | **R. Giskard Reventlov** | Containers, Traefik, networking, service deployments | haiku → sonnet |
| 🎨 Creative Director | **R. Andrew Martin** | Blog posts, announcements, naming, content strategy | sonnet |

All names follow Asimov's robot naming convention (R. = Robot).

---

## How it works

```
You → R. Sami (main OpenClaw session)
         ↓
    R. Daneel (Co-ordinator)
         ↓ classifies + routes
    R. Sammy  /  R. Giskard  /  R. Andrew
         ↓ results
    R. Daneel → aggregates
         ↓
    R. Sami → You
```

R. Daneel never executes specialist tasks directly — he routes, tracks, and synthesises. If an agent times out, R. Daneel reports to you and asks permission before dispatching an investigation.

---

## Quick start

```bash
# 1. Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon

# 2. Clone
git clone https://github.com/SilentAxis/openclaw-agent-coordinator /opt/OpenclawAgent
cd /opt/OpenclawAgent

# 3. Configure
cp .env.example .env
# Edit .env — add ANTHROPIC_API_KEY at minimum

# 4. Setup
./setup.sh

# 5. Start
OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json openclaw gateway start

# 6. Test
./tests/run-integration-tests.sh
```

> **Full installation guide:** [INSTALL.md](INSTALL.md)

---

## Project structure

```
/opt/OpenclawAgent/
  README.md                      ← This file
  INSTALL.md                     ← Full install guide
  setup.sh                       ← Idempotent setup script
  openclaw.json                  ← Fleet config (use with OPENCLAW_CONFIG_PATH)
  .env.example                   ← API key template
  config/
    agents.json                  ← Agent registry
    cron-sessions.json           ← Persistent session definitions
  coordinator/workspace/         ← R. Daneel's identity + memory
  python-dev/workspace/          ← R. Sammy's identity + memory
  docker-infra/workspace/        ← R. Giskard's identity + memory
  creative-director/workspace/   ← R. Andrew's identity + memory
  docs/
    dependencies.md              ← Full dependency reference
  tests/
    integration-test-plan.md     ← Test scenarios + pass criteria
    run-integration-tests.sh     ← Automated test runner
```

---

## Requirements

- OpenClaw (Node 22+ / 24 recommended)
- `uv` / `uvx` — for jCodeMunch + jDocMunch MCP tools
- `python3 ≥ 3.11`
- `ANTHROPIC_API_KEY`
- Docker (optional — only needed for R. Giskard)

> Full details: [docs/dependencies.md](docs/dependencies.md)

---

## Phase roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| **1 — Build** | 4 agents, delegation loop, identity files, setup script | ✅ Complete |
| 2 — Validate | Live integration tests, cron sessions, model tuning | 🔜 |
| 3 — Local Nodes | Fileserver, pfSense, QuantumForge, Mac Mini agents | 🔜 |
| 4 — Full Fleet | Parallel execution, cross-node co-ordination | 🔜 |

---

## References

- OpenClaw docs: https://docs.openclaw.ai
- Vikunja project: #24 — OpenClaw Agent Co-ordinator
- Architecture doc: `openclaw-vault/docs/plans/agent-coordinator-architecture.md`
