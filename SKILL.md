---
name: yieldingbear
description: Install and operate Yielding Bear — unified OpenAI-compatible LLM gateway with cost routing, free-model catalog, and agent CLI setup for OpenClaw/Hermes. Use when wiring YIELDINGBEAR_API_KEY, installing the agent CLI, listing free vs paid models, or replacing OpenAI base_url with yieldingbear.com.
homepage: https://yieldingbear.com
metadata:
  author: Yielding Bear LLC
  version: "2.0.0"
  openclaw:
    requires:
      bins: ["curl", "bash"]
    primaryEnv: YIELDINGBEAR_API_KEY
    emoji: "🐻"
---

# Yielding Bear — agent CLI + gateway skill

**ClawHub skill (not an OpenClaw provider plugin).**  
OpenClaw plugins register Node SDK providers (`openclaw.plugin.json`). This package is install scripts + agent playbook for the hosted gateway — the right ClawHub artifact, and updatable via `clawhub update yieldingbear`.

| | |
|--|--|
| Base URL | `https://yieldingbear.com/api/v1` (**not** `api.yieldingbear.com`) |
| Keys | `yb_live_sk_…` from https://yieldingbear.com/dashboard?tab=developer |
| Default router | `yieldingbear/grizzly-1.0g` |
| Free label rule | `is_free` only when OpenRouter `:free` / $0 upstream (catalog SSOT: Supabase `model_config`) |

## Install (one shot)

```bash
# From ClawHub
clawhub install yieldingbear

# Or curl installer (same script bundled here)
curl -fsSL https://yieldingbear.com/install.sh | bash
# Non-interactive:
YIELDINGBEAR_API_KEY=yb_live_sk_… curl -fsSL https://yieldingbear.com/install.sh | bash
```

Bundled installer:

```bash
bash "$(dirname "$0")/scripts/install.sh"
# or after install:
bash ~/.openclaw/skills/yieldingbear/scripts/install.sh
```

What it writes (mode 600/700):

| Runtime | Key file | Config | Env |
|---------|----------|--------|-----|
| Hermes | `~/.hermes/secrets/yieldingbear-token` | `~/.hermes/config/yieldingbear.json` | `~/.hermes/config/env.sh` |
| OpenClaw | `~/.openclaw/secrets/yieldingbear-token` | `~/.openclaw/config/yieldingbear.json` | `~/.openclaw/config/env.sh` |
| Shell | `~/.config/yieldingbear/secrets/yieldingbear-token` | `~/.config/yieldingbear/yieldingbear.json` | `…/env.sh` |

Also sets `YIELDINGBEAR_API_KEY`, `YIELDINGBEAR_BASE_URL`, `YIELDINGBEAR_DEFAULT_MODEL`.

## Doctor / status

```bash
bash scripts/yb.sh doctor
bash scripts/yb.sh status
bash scripts/yb.sh models          # live catalog; free tagged [free]
bash scripts/yb.sh models --free   # free only
bash scripts/yb.sh smoke           # tiny chat against default or free model
```

## OpenAI-compatible drop-in

```python
from openai import OpenAI
client = OpenAI(
    api_key=open(os.path.expanduser("~/.hermes/secrets/yieldingbear-token")).read().strip(),
    base_url="https://yieldingbear.com/api/v1",
)
r = client.chat.completions.create(
    model="yieldingbear/grizzly-1.0g",
    messages=[{"role": "user", "content": "hi"}],
)
```

```bash
source ~/.openclaw/config/env.sh   # or Hermes/shell path above
curl -sS https://yieldingbear.com/api/v1/chat/completions \
  -H "Authorization: Bearer $YIELDINGBEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"liquid/lfm-2.5-2.6b","messages":[{"role":"user","content":"ping"}],"max_tokens":8}'
```

## Models

Live catalog: `GET https://yieldingbear.com/api/v1/models`  
Each row exposes `is_free` / `is_active`. **Only true $0 upstreams are labeled free.**

Free (active as of 2026-09-01 audit):

- `cohere/north-mini-code`
- `dots-studio/dots-3-note-preview`
- `liquid/lfm-2.5-2.6b`
- `nvidia/nemotron-3-nano-30b`
- `nvidia/nemotron-3-super-120b`
- `nvidia/nemotron-3-ultra-550b`
- `nvidia/nemotron-3.5-lightning`
- `poolside/laguna-s`
- `poolside/laguna-xs`

Paid examples (do **not** label free): `openai/gpt-oss-20b`, `yieldingbear/grizzly-1.0g`, Groq/DeepInfra/OpenAI catalog IDs.

Virtual routers: `yieldingbear/grizzly-1.0g`, `yieldingbear/grizzly-1.0g-pro`, camp variants (`…-finance`, etc.).

## Hermes CLI

If Hermes is installed: `/yieldingbear setup|status|key|models|usage|set|show|reset`

## Upgrade path

```bash
clawhub update yieldingbear
# re-run installer to refresh config schema (idempotent; keeps key file)
bash ~/.openclaw/skills/yieldingbear/scripts/install.sh
```

Config JSON `version` field tracks installer schema (semver date `YYYY.MM.DD` or skill `2.x`).

## Security

- Never commit `yb_live_sk_*` or put keys in SKILL.md / git.
- Key files mode `600`; secrets dirs `700`.
- Prefer reading key from file over echoing into process lists.

## Links

- Docs: https://yieldingbear.com/docs  
- Developers: https://yieldingbear.com/developers  
- Dashboard: https://yieldingbear.com/dashboard  
- ClawHub: https://clawhub.ai/yieldingbear/yieldingbear  
