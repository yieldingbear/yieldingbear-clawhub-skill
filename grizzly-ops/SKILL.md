---
name: grizzly-ops
description: "Always-on Yielding Bear spend rules: Auto rails, honest-free first, cache-shaped prompts, receipts, burn-down. Not an installer."
version: 1.0.0
author: Yielding Bear
license: MIT
homepage: https://yieldingbear.com
metadata:
  openclaw:
    always: true
  hermes:
    tags: [yieldingbear, grizzly, cost, routing, ops]
---

# grizzly-ops (always on)

Force cheaper agent behavior every turn. This is **not** the installer — install `grizzly` first for key + doctor + smoke.

Hermes has no `before_model_resolve` hook: follow these rules + keep default model `yieldingbear/grizzly-1.0g-pro`. OpenClaw: also install the companion `plugin/` for real model overrides.

Config (override defaults): runtime `config/yieldingbear/grizzly-ops.json` (see `grizzly-ops.example.json`). CLI: `yb.sh` in the installer skill.

## Rules (imperative)

### 1. Default rail
- All LLM calls go through Yielding Bear (`https://yieldingbear.com/api/v1`).
- Default model: `yieldingbear/grizzly-1.0g-pro` unless a pin or policy says otherwise.
- Never set `ANTHROPIC_API_KEY` / raw OpenAI as the primary path after install.

### 2. Skill-to-rail policy (before the turn)
Classify the turn:

| Rail | Use when |
|------|----------|
| **high** | hard code review, architecture, security, multi-file refactors; vision only if images are in the turn |
| **mid** | normal implement, search, email draft |
| **free** | “ok”, “thanks”, notify, format, summarize, triage, listing models |

Map known skill names (defaults; override in `grizzly-ops.json` → `skill_rails`):

- **high:** github (review), code-review, security, architecture
- **mid:** implement, search, browser, email draft
- **free:** summarize, notify, gog (notify/list), triage, format

Defaults are **cost-conservative**, not quality-max. Prefer free/mid when unsure.

### 3. Honest-free first
- Before proposing Claude/GPT/Sonnet, run `yb.sh models --free` (live).
- If a free model can do the job, say so and use it.
- **Never** use a stale hardcoded free list.

### 4. `yb.sh why` before a paid pin
- Leaving Auto to pin a paid model: run `yb.sh why` (or `explain`) and state high vs mid vs free **$/1M from live data**.
- If health fails: say you don’t have live prices — **do not invent numbers**.

### 5. Cache-shaped prompting
- Keep system prompt + tool schemas a **stable prefix**.
- Put variable user text and tool results at the **tail**.
- Truncate tool payloads before paid context: strip HTML, base64, huge stack traces, raw images-as-text.

### 6. Cheap compact, then think
- If context is fat: summarize older turns on free/mid, then do the actual step on the needed rail.

### 7. Retry-storm killer
- **429:** backoff/queue; do **not** upgrade rail.
- **403 high-rail:** retry at most once, then mid/free.
- Never triple-retry frontier.
- Free is 60 RPM — treat 429 as expected on free, not as “need Opus.”

### 8. Promote-on-correction
- User says answer was too dumb / “use the good model” / retries → pin that skill or pattern to **high** for a decaying window (default **7 days**) in local state (`promote` in ops config/state).
- Inverse: similar turn succeeded on free without correction → stay free.

### 9. Turn receipts
After each completion, append one JSON line to  
`~/.hermes|openclaw|config/yieldingbear/receipts.jsonl`  
(or path from config):

```json
{"ts":"...","cost_usd":0,"routed_to":"...","cache_hit":true,"skill":"...","tokens_in":0,"tokens_out":0,"rail":"mid"}
```

Use fields the API actually returns (`cost_usd`, `routing.routed_to`, cache headers/body). **If a field is missing, omit it — do not fake it.**  
CLI helper: `yb.sh receipts --append '{...}'` or agent writes the line directly.

### 10. Session burn-down
Track session spend/tokens from receipts. Defaults (override in `grizzly-ops.json`):

| Threshold | Action |
|-----------|--------|
| warn `$1` | warn user |
| `$3` | demote high → mid |
| `$8` | demote mid → free |
| `$15` | hard stop paid unless user overrides |

Pinned-high skills may exempt **one** turn, not the whole session.  
CLI: `yb.sh spend [--session|--today|--forecast]`.

### 11. Speculative escalate (opt-in)
- Config `speculative_escalate: false` by default.
- If enabled: try mid/free first; if a cheap quality check fails, retry **once** on high via YB (so semantic cache can hit). Do not double-bill unexpectedly.

### 12. Daily circuit breaker
- `daily_usd_cap` in config; when crossed, force free-only until next UTC day or user override.

### 13. Virtual key bindings (optional)
- `yb.sh vk-bind <skill> <rail>` records bindings in `grizzly-ops.json`.
- Live minting is **blocked on API** until documented; config shape only.

## CLI (installer `yb.sh`)

```bash
yb.sh set-routing auto|manual
yb.sh why
yb.sh spend [--session|--today|--forecast]
yb.sh receipts --tail [N]
yb.sh vk-bind <skill> <high|mid|free>   # config only until API exists
```

## Install order

1. `clawhub install grizzly` + `bash scripts/install.sh`
2. Install this skill (`grizzly-ops`) into the agent skills path
3. OpenClaw: `openclaw plugins install --link ./plugin` + gateway restart

**Do not publish to ClawHub until Laurence says “publish.”**
