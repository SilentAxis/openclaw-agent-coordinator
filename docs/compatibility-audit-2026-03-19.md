# Compatibility Audit — 2026-03-19

## Scope
Review of `openclaw-agent-coordinator` against OpenClaw 2026.3.14 CLI/config behavior.

## Findings

1. `openclaw sessions list` is no longer valid on current CLI.
   - Use `openclaw sessions --all-agents` for cross-agent visibility.
2. `openclaw sessions send` is no longer present in current CLI.
   - Use `openclaw agent --agent <id> --session-id <id> --message <text>` or API/session tools.
3. Cron session pinning in setup used `--session <target>` with short keys.
   - Updated to `--session-key <full-session-key>`.
4. Setup only validated JSON syntax.
   - Added OpenClaw schema validation via `openclaw config validate`.

## Security/ops notes

- `openclaw.json` currently contains permissive Control UI settings (`allowInsecureAuth`, `dangerously*` flags).
- Gateway token is stored in config file (expected but sensitive).
- Keep this repo's config as a template; inject secrets from env during setup.


## Local hardening changes applied

- Changed project config default bind from `lan` to `loopback`
- Replaced wildcard Control UI origins with localhost-only origins
- Disabled `allowInsecureAuth`, `dangerouslyDisableDeviceAuth`, and `dangerouslyAllowHostHeaderOriginFallback`
- Added gateway auth rate limiting
- Replaced committed gateway token with placeholder `__SET_OPENCLAW_GATEWAY_TOKEN__`
- Added explicit `plugins.entries.complexity-router` config to document intended routing behavior
