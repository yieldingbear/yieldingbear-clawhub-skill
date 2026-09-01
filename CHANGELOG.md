# Changelog

## 2.1.0 — 2026-09-01

### Changed
- Marketable, punchy SKILL.md aligned to site voice: **One API. 100+ LLMs. Smart Routing.**
- Frontmatter description drives agent routing + ClawHub search.
- Dual feature tables: Why Yielding Bear + Why this skill.
- CTAs to yieldingbear.com (home, docs, pricing, developers, how-it-works).
- Savings framed as illustrative (not a hard guarantee).
- Free tier: honest $0 upstream only.

### Unchanged
- Install scripts, doctor CLI, correct base URL `https://yieldingbear.com/api/v1`.
- No platform secrets in package or git.

## 2.0.0 — 2026-09-01

### Why skill (not OpenClaw plugin)
- ClawHub publishes **skills**; OpenClaw **plugins** are Node SDK provider extensions.
- Yielding Bear agent setup is install + config + playbook → skill is the correct updatable artifact.

### Added
- Bundled `scripts/install.sh` (Hermes / OpenClaw / shell).
- `scripts/yb.sh` doctor, status, models, smoke.
- Correct base URL everywhere (removed stale `api.yieldingbear.com`).
- Free-model list aligned to OpenRouter `:free` / $0 only.

### Changed
- `openai/gpt-oss-20b` is **paid** (not free).
