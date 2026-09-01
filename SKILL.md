---
name: yieldingbear
description: "One API. 100+ LLMs. Smart Routing. Wire OpenClaw/Hermes to Yielding Bear — Grizzly auto-routes, free tier, doctor CLI. Start at https://yieldingbear.com"
homepage: https://yieldingbear.com
metadata:
  author: Yielding Bear LLC
  version: "2.1.0"
  openclaw:
    requires:
      bins: ["curl", "bash"]
    primaryEnv: YIELDINGBEAR_API_KEY
    emoji: "🐻"
---

# Yielding Bear

**One API. 100+ LLMs. Smart Routing.**  
Built for builders, agents, and SMBs — cheap when it’s easy, frontier when it’s not.

→ **https://yieldingbear.com**

## Why Yielding Bear

| | |
|--|--|
| **One key** | Drop-in OpenAI-compatible base URL — GPT, Claude, Gemini, Llama, and more |
| **Smart routing** | `yieldingbear/grizzly-1.0g` picks cost vs capability per request |
| **Real savings** | Up to ~60–80% vs retail (illustrative) — right model every call |
| **Honest free** | True $0 upstream free models only — no fake “free” paid rows |
| **Agents-first** | Free key → usage; **Grizzly Pro $99** when you scale (25M tokens) |
| **Dashboard** | Keys, spend, models — [developers](https://yieldingbear.com/dashboard?tab=developer) |

## Why this skill

| | |
|--|--|
| **1-command install** | Hermes, OpenClaw, or shell — keys mode 600, never in git |
| **Doctor CLI** | `yb.sh doctor` / `models` / `smoke` — prove the wire before you ship |
| **Live catalog** | Free tags from live API — not a stale hardcoded list |
| **Updatable** | `clawhub update yieldingbear` — no fork rot |

## Get started (90 seconds)

1. **Sign up + key** → https://yieldingbear.com/dashboard?tab=developer  
2. **Install skill**
   ```bash
   clawhub install yieldingbear
   bash ~/.openclaw/skills/yieldingbear/scripts/install.sh
   # or: curl -fsSL https://yieldingbear.com/install.sh | bash
   ```
3. **Pick a model** (installer prompts) — Grizzly router, a free model, or any paid ID  
4. **Ship**
   ```bash
   bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh doctor
   bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh models --free
   bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh smoke
   ```

Non-interactive:

```bash
YIELDINGBEAR_API_KEY=yb_live_sk_… \
YIELDINGBEAR_DEFAULT_MODEL=yieldingbear/grizzly-1.0g \
  bash scripts/install.sh
```

## Wire once

| | |
|--|--|
| Base URL | `https://yieldingbear.com/api/v1` |
| Key | `yb_live_sk_…` (customer key only — never platform secrets) |
| Default router | `yieldingbear/grizzly-1.0g` |

```python
from openai import OpenAI
client = OpenAI(
    api_key="yb_live_sk_…",  # from dashboard
    base_url="https://yieldingbear.com/api/v1",
)
client.chat.completions.create(
    model="yieldingbear/grizzly-1.0g",
    messages=[{"role": "user", "content": "hi"}],
)
```

## Links

- Site: https://yieldingbear.com  
- How it works: https://yieldingbear.com/how-it-works  
- Docs: https://yieldingbear.com/docs  
- Pricing / Pro: https://yieldingbear.com/pricing  
- Keys: https://yieldingbear.com/dashboard?tab=developer  
- ClawHub: https://clawhub.ai/yieldingbear/yieldingbear  
- Source: https://github.com/yieldingbear/yieldingbear-clawhub-skill  

## Security (hard rules)

- **Never** commit real `yb_live_sk_*`, OpenRouter, Supabase service role, LiteLLM, or ClawHub tokens.
- Customer keys live only in `~/.hermes|openclaw|config/yieldingbear/secrets/` (mode 600).
- Free path = true free upstream only. Paid models require balance.

## Update

```bash
clawhub update yieldingbear
```
