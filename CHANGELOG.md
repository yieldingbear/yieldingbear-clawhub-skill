# Changelog

## 2.2.0 — 2026-09-01

### Added
- Full install walkthrough: signup → Pro / credits / free → live model library with $/1M.
- CLI signup offer path: `$10 off Pro × first 3 months` via `https://yieldingbear.com/offer/cli10x3`.
- `yb.sh set-model`, `yb.sh explain`, richer `models` (`--paid` / `--routers`) + routing doctor check.
- Honest routing copy: high/mid/free cascade, live pricing, cache + optional bandit (when enabled).

### Fixed
- Chat Authorization headers use real `$KEY` / `$api_key` (broken `***` placeholder removed).

### Notes
- Referral `$20` first-month stays separate; never stacks with CLI `$10×3`.

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
