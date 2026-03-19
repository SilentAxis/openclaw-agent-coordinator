# Refactor Plan — OpenClaw Agent Coordinator

## Goal
Make the repo reproducible and compatible with current OpenClaw (2026.3.14+).

## Phase 1 — CLI/Schema Compatibility (done in local patch)
- [x] Replace `openclaw sessions list` -> `openclaw sessions --all-agents`
- [x] Replace `openclaw sessions send` flow in integration tests
- [x] Use `--session-key` when creating cron jobs
- [x] Add schema validation (`openclaw config validate`) in setup

## Phase 2 — Security Hardening
- [ ] Remove permissive Control UI defaults from project config
- [ ] Add documented secure profile (LAN-only, trusted origins, no dangerous flags)
- [ ] Move secret-bearing values to env/template substitution

## Phase 3 — Test Modernization
- [ ] Rework test runner to assert structured outputs (`--json` mode + jq when present)
- [ ] Add preflight check for required agents and gateway status
- [ ] Add non-destructive smoke test mode

## Phase 4 — Packaging/Docs
- [ ] Add `openclaw.template.json` and generate runtime config from `.env`
- [ ] Document exact supported OpenClaw version range
- [ ] Add quick troubleshooting matrix (auth errors, missing sessions, cron failures)
