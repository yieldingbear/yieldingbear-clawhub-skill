# Yielding Bear — Grizzly ClawHub package

Three artifacts (do **not** replace the installer with the plugin):

| Artifact | Path | Role |
|----------|------|------|
| **grizzly** (public installer skill) | `SKILL.md` + `scripts/` | One key, Auto routing, doctor/smoke |
| **grizzly-ops** (always-on skill) | `grizzly-ops/` | Spend rules, rails, receipts |
| **OpenClaw plugin** (optional) | `plugin/` | `before_model_resolve` enforcement |

Live listing: https://clawhub.ai/yieldingbear/skills/grizzly  
Product gateway: **https://yieldingbear.com/api/v1** only (never `api.yieldingbear.com`, never bare `/v1`).

**Do not `clawhub publish` until Laurence says “publish.”** This repo and the live listing may diverge until then.

## Install order

1. **Installer skill**
   ```bash
   clawhub install grizzly
   # or OpenClaw:
   openclaw skills install @yieldingbear/grizzly
   bash scripts/install.sh
   ```
2. **Ops skill** — copy/link `grizzly-ops/` into the agent skills path (Hermes/OpenClaw).  
   OpenClaw may honor `metadata.openclaw.always: true`. Hermes: follow the skill rules + default model `yieldingbear/grizzly-1.0g-pro`.
3. **OpenClaw plugin** (optional but needed for real model overrides):
   ```bash
   openclaw plugins install --link ./plugin --force
   openclaw plugins enable grizzly-ops
   openclaw gateway restart
   ```

## CLI (`scripts/yb.sh`)

```bash
yb.sh doctor
yb.sh set-routing auto|manual [model]
yb.sh why | explain
yb.sh models [--free|--paid|--routers]
yb.sh smoke [model]
yb.sh spend [--session|--today|--forecast]
yb.sh receipts --tail [N] | --append '<json>' | --path
yb.sh vk-bind <skill> <high|mid|free>   # config only until VK API exists
```

Keys: `YIELDINGBEAR_API_KEY` (legacy `YB_API_KEY`).  
Prefixes: `grizzly_live_sk_…` and legacy `yb_live_sk_…`.  
Secrets: `~/.hermes|openclaw|config/yieldingbear/secrets/` mode `600`.

## Honest free / routing

- Free list = live `GET /api/v1/models` (`yieldingbear.data[].is_free`) — never hardcode.
- Rails + $/1M when available: `GET /api/health/grizzly-routing` and `GET /api/public/routing-recommendations`.
- Free plan: **60 RPM**. A 429 on free is expected under load — not a signal to jump to frontier.

## Tests

```bash
bash scripts/yb.sh why          # needs network
cd plugin && npm test           # offline unit tests
bash tests/yb_cli_smoke.sh      # offline CLI surface checks
```

## Version

Installer skill **2.5.0**. Ops skill **1.0.0**. Plugin **1.0.0**.
