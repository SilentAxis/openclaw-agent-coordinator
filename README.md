# OpenClaw Agent Co-ordinator

**Project:** OpenClaw Agent Co-ordinator  
**Phase:** 1 — Minimal Viable Co-ordinator  
**Target:** March 25, 2026  
**Vikunja:** Project #24  

---

## ⚠️ Deployment Note

This project is **NOT** the running OpenClaw instance at `~/.openclaw/`.  
This is a **standalone deployment** for a new device.

Use `OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json` when starting OpenClaw on the target device.

---

## Agent Fleet

| Agent | Name | Emoji | Model | Role |
|-------|------|-------|-------|------|
| `coordinator` | R. Daneel Olivaw | 🧠 | sonnet | Routes, delegates, aggregates |
| `python-dev` | R. Sammy | 🐍 | haiku → sonnet | Python, scripts, automation |
| `docker-infra` | R. Giskard Reventlov | 🐳 | haiku → sonnet | Containers, networking, infra |
| `creative-director` | R. Andrew Martin | 🎨 | sonnet | Blog, copy, content, naming |

All names are Asimov-inspired (The Robot Series).

---

## Directory Structure

```
/opt/OpenclawAgent/
  openclaw.json                  ← Main config for this deployment
  README.md                      ← This file
  coordinator/
    workspace/                   ← R. Daneel's workspace
      IDENTITY.md
      SOUL.md
      AGENTS.md
      memory/
    agent/                       ← Auth profiles, model registry
    sessions/                    ← Persistent session store
  python-dev/
    workspace/                   ← R. Sammy's workspace
    agent/
    sessions/
  docker-infra/
    workspace/                   ← R. Giskard's workspace
    agent/
    sessions/
  creative-director/
    workspace/                   ← R. Andrew's workspace
    agent/
    sessions/
```

---

## Delegation Flow

```
Mike → R. Sami (main session on host)
         ↓ sessions_send
    R. Daneel (session:coordinator-agent)
         ↓ sessions_send
    R. Sammy  / R. Giskard / R. Andrew
         ↓ result
    R. Daneel → aggregates
         ↓ sessions_send
    R. Sami → Mike
```

## Timeout Protocol

If any agent times out:
1. Agent reports to R. Daneel immediately
2. R. Daneel notifies Mike via R. Sami
3. R. Daneel asks: *"Should I dispatch R. Giskard / node agent to investigate?"*
4. Mike approves — R. Daneel dispatches
5. Local node agents (Phase 3) handle server-level investigation

---

## Deployment Instructions (Target Device)

```bash
# 1. Install OpenClaw on target device
# 2. Copy this directory
scp -r /opt/OpenclawAgent user@target:/opt/OpenclawAgent

# 3. Set API keys in environment
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...      # optional
export GOOGLE_API_KEY=...      # optional

# 4. Start OpenClaw pointing at this config
OPENCLAW_CONFIG_PATH=/opt/OpenclawAgent/openclaw.json openclaw gateway start
```

---

## Phase Roadmap

| Phase | Scope | Target |
|-------|-------|--------|
| **1 — Build** ← current | 4 agents, delegation loop, identity files | Mar 25 |
| 2 — Validate | End-to-end test, cron sessions, model tuning | Apr 10 |
| 3 — Local Nodes | Fileserver, pfSense, QuantumForge, Mac Mini agents | Apr 20 |
| 4 — Integration | Full fleet, parallel execution | Apr 28 |
| 5 — Validation | Test suite, Ollama eval | May 5 |

---

## References

- Architecture: `~/openclaw-vault/docs/plans/agent-coordinator-architecture.md`
- Phase 1 plan: `~/openclaw-vault/docs/plans/phase1-agent-coordinator.md`
- Sessions research: `~/openclaw-vault/docs/plans/persistent-sessions-research.md`
