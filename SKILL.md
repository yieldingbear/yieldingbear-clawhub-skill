---
name: Grizzly
description: "Installer for Yielding Bear: one API key, Auto routing via yieldingbear/grizzly-1.0g-pro, doctor + smoke. ClawHub slug grizzly."
version: 2.5.0
author: Yielding Bear
license: MIT
homepage: https://yieldingbear.com
metadata:
  openclaw:
    requires:
      env:
        - YIELDINGBEAR_API_KEY
    primaryEnv: YIELDINGBEAR_API_KEY
    install:
      - kind: script
        script: scripts/install.sh
---

# Grizzly (Yielding Bear installer)

Wire one key into Hermes or OpenClaw, default **Auto** routing through `yieldingbear/grizzly-1.0g-pro`, and verify with doctor/smoke.

> Public installer skill only. Cost loop = optional **grizzly-ops** skill + OpenClaw **plugin/** (`before_model_resolve`). Do not replace this installer with a plugin.

## Install

```bash
# ClawHub
clawhub install grizzly
# or OpenClaw
openclaw skills install @yieldingbear/grizzly

# Legacy alias (docs only): clawhub install yieldingbear
bash scripts/install.sh
```

Env / flags:

```bash
YIELDINGBEAR_API_KEY=grizzly_live_sk_… bash scripts/install.sh
# legacy env still accepted by yb.sh: YB_API_KEY
# non-interactive:
YIELDINGBEAR_API_KEY=… YB_ROUTING_MODE=auto bash scripts/install.sh --yes
```

Key prefixes accepted: `grizzly_live_sk_` (canonical), `yb_live_sk_` / `yb_test_sk_` (legacy).

## Canonical endpoints

| Use | URL |
|-----|-----|
| OpenAI-compatible API | `https://yieldingbear.com/api/v1` |
| Models (live catalog) | `GET /api/v1/models` → prefer `yieldingbear.data` |
| Routing health (prices) | `GET /api/health/grizzly-routing` |
| Public rail recs | `GET /api/public/routing-recommendations` |

Never use `api.yieldingbear.com` or bare `/v1`.

## Defaults

| Setting | Value |
|---------|--------|
| Routing mode | **auto** |
| Default model | `yieldingbear/grizzly-1.0g-pro` |
| Manual pin | `yb.sh set-model <catalog-id>` or `yb.sh set-routing manual [id]` |

Installer prompts Auto vs Manual; default Auto.

## CLI (`scripts/yb.sh`)

```bash
yb.sh status
yb.sh doctor          # models + routing health + free smoke + fake-Free warn
yb.sh models [--free|--paid|--routers]   # live catalog only
yb.sh set-routing auto|manual [model_id]
yb.sh set-model <id>  # manual pin; router id → auto
yb.sh why | explain   # live high/mid/free ids + $/1M when health returns them
yb.sh smoke [model]   # prefers a live free catalog id when possible
```

## Secrets

Customer keys only under runtime config, mode 600:

- `~/.hermes/config/yieldingbear/secrets/`
- `~/.openclaw/config/yieldingbear/secrets/`
- `~/.config/yieldingbear/secrets/`

Never commit keys. Env: `YIELDINGBEAR_API_KEY` (canonical), `YB_API_KEY` (legacy).

## Product facts (do not invent)

- One key; 100+ catalog; Auto high/mid/free via `yieldingbear/grizzly-1.0g-pro`.
- Honest free = true $0 upstream only — from live catalog, never a hardcoded free list.
- Credits never expire. Grizzly Pro $99/mo; CLI offer $10 off first 3 months (`/offer/cli10x3`). Referral $20 first month does not stack with CLI offer.
- Free plan: 60 RPM. Heavy agents may 429 — not unlimited.
- Do not claim savings percentages, ARR, user counts, raise amounts, or SOC2.

## Optional cost loop

1. Install this skill (installer).
2. Install **grizzly-ops** (always-on spend rules) when available in-repo / ClawHub.
3. OpenClaw only: `openclaw plugins install --link ./plugin` + gateway restart for real `before_model_resolve` routing. Hermes has no model-resolve hook — default model + ops skill is the path.

**Do not clawhub publish until Laurence explicitly says "publish."**
