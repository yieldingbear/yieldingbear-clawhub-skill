# Changelog

## 2.5.0+ops — 2026-09-02 (same branch)

### grizzly-ops always-on skill
- New `grizzly-ops/` skill (`always: true` for OpenClaw metadata).
- Imperative spend rules; no savings % claims.
- `yb.sh spend`, `receipts`, `vk-bind` (VK mint blocked on API).
- Example config `grizzly-ops.example.json` with burn-down thresholds.

## 2.5.0 — 2026-09-02

### Slug unification (repo ↔ live listing)
- Skill name/slug **grizzly** (legacy docs alias: `yieldingbear`).
- Install: `clawhub install grizzly` / `openclaw skills install @yieldingbear/grizzly`.
- Keys: canonical `grizzly_live_sk_`; legacy `yb_live_sk_` / `yb_test_sk_` still accepted.
- Env: `YIELDINGBEAR_API_KEY` canonical; `YB_API_KEY` legacy alias in `yb.sh` + installer.
- Base URL only `https://yieldingbear.com/api/v1`.
- Default routing **auto** → `yieldingbear/grizzly-1.0g-pro`.
- `yb.sh set-routing auto|manual`; `set-model` remains manual pin.
- `yb.sh why` alias of explain; live high/mid/free ids + $/1M from `/api/health/grizzly-routing` when present (no invented prices).
- Doctor: models, routing-recommendations, grizzly-routing health, fake `(Free)` warn, free-model smoke.
- Models list prefers `yieldingbear.data` live catalog (`is_free`, pricing).
- `sync_server_prefs` now sends actual routing mode (auto|manual), not hard-coded auto.
- No savings-percentage claims in skill, CLI, or commit messages.

## 2.4.x — live ClawHub only (not fully in git)
Live listing advanced past repo 2.2.0 with set-routing + grizzly slug. This release re-syncs git to that identity and tightens doctor/why.

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
