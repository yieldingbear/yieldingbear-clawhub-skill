---
name: yieldingbear
description: "One API. 100+ LLMs. Smart Routing. Wire OpenClaw/Hermes to Yielding Bear — Grizzly auto-routes high/mid/free, free tier, doctor CLI, $10×3 Pro signup offer. Start at https://yieldingbear.com"
homepage: https://yieldingbear.com
metadata:
  author: Yielding Bear LLC
  version: "2.2.0"
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
| **Smart routing** | `yieldingbear/grizzly-1.0g-pro` classifies prompt need → **high / mid / free** with live $/1M awareness |
| **Cache + optimize** | Server semantic cache + prompt-cache flags; optional bandit self-improve on outcomes (when enabled) |
| **Real savings** | Up to ~60–80% vs retail (illustrative) — right model every call |
| **Honest free** | True $0 upstream free models only — no fake “free” paid rows |
| **Agents-first** | Free key → usage; **Grizzly Pro $99** when you scale |
| **Dashboard** | Keys, spend, models — [developers](https://yieldingbear.com/dashboard?tab=developer) |

## Why this skill

| | |
|--|--|
| **1-command install** | Hermes, OpenClaw, or shell — keys mode 600, never in git |
| **Full walkthrough** | Signup → Pro **or** credits **or** free → live model library → switch default |
| **CLI Pro offer** | **$10 off first 3 months** ($89→$99) via `/offer/cli10x3` (not stacked with referral) |
| **Doctor CLI** | `yb.sh doctor` / `models` / `set-model` / `explain` / `smoke` |
| **Live catalog** | Free tags + $/1M from live API |
| **Updatable** | `clawhub update yieldingbear` |

## Get started (2 minutes)

```bash
# One-liner (site install — same scripts as skill)
curl -fsSL https://yieldingbear.com/install.sh | bash

# Or ClawHub
clawhub install yieldingbear
bash ~/.openclaw/skills/yieldingbear/scripts/install.sh
```

Installer walks you through:

1. **Account** — opens signup with CLI offer cookie  
2. **API key** — paste `yb_live_sk_…` (validated)  
3. **Plan** — Pro ($10×3) | credits | stay free  
4. **Model** — live library with $/1M; switch anytime  

```bash
bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh doctor
bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh models --free
bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh set-model liquid/lfm-2.5-2.6b
bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh explain
bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh smoke
```

Non-interactive:

```bash
YIELDINGBEAR_API_KEY=yb_live_sk_… \
YIELDINGBEAR_DEFAULT_MODEL=yieldingbear/grizzly-1.0g-pro \
  bash scripts/install.sh
```

## Wire once

| | |
|--|--|
| Base URL | `https://yieldingbear.com/api/v1` |
| Key | `yb_live_sk_…` (customer key only — never platform secrets) |
| Default router | `yieldingbear/grizzly-1.0g-pro` |

```python
from openai import OpenAI
client = OpenAI(
    api_key="yb_live_sk_…",  # from dashboard
    base_url="https://yieldingbear.com/api/v1",
)
client.chat.completions.create(
    model="yieldingbear/grizzly-1.0g-pro",
    messages=[{"role": "user", "content": "hi"}],
)
```

## Offers (do not stack)

| Path | Deal |
|--|--|
| **CLI / install / ClawHub** | $10 off Pro × first **3 months** ($89 then $99) — `/offer/cli10x3` |
| **Referral (bound invitee)** | $20 off **first** Pro month (~$79 once); referrer gets $10 credits on paid Pro |
| Priority | Referral wins if both eligible; never both coupons on one Checkout |

## Routing (what’s real)

- Grizzly classifies reasoning need → high / mid / low  
- Pro defaults: frontier high, fast mid, free/active low (soft-fail → mid)  
- Billing uses live input/output $/1M  
- Caching + bandit self-improve are **server flags** — `yb.sh doctor` / `explain` report health when available  
- Not a promise of RL-perfect routing on every account  

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
