# Changelog

## 2.0.0 — 2026-09-01

### Why skill (not OpenClaw plugin)
- ClawHub publishes **skills**; OpenClaw **plugins** are Node SDK provider extensions (`openclaw.plugin.json`).
- Yielding Bear agent setup is install + config + playbook → skill is the correct updatable artifact.

### Added
- Bundled `scripts/install.sh` (Hermes / OpenClaw / shell runtimes).
- `scripts/yb.sh` doctor, status, models, smoke.
- Correct base URL `https://yieldingbear.com/api/v1` everywhere (removed stale `api.yieldingbear.com`).
- Free-model list aligned to OpenRouter `:free` / $0 only (2026-09-01 catalog audit).
- Semver + changelog for future `clawhub update`.

### Changed
- `openai/gpt-oss-20b` is **paid** (not free).
- Removed free labels from demoted/dead free IDs (`stealth/ox-alpha`, `nvidia/nemotron-nano-9b`, `dots-studio/dots-3-note`).
- Installer free fallback uses a true free model, not gpt-oss-20b.

### Security
- No embedded API keys; file-based secrets only.

## 1.0.0 — 2026-03-28
- Initial ClawHub publish (docs-only skill).
