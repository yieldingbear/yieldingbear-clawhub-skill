# WS0 mismatch ledger (2026-09-02)

## Sources
| Source | What |
|--------|------|
| Repo main @ pre-branch | SKILL name `yieldingbear` v2.2.0; CLI: doctor/status/models/set-model/explain/smoke; keys `yb_live_sk_`; no set-routing |
| Live ClawHub listing | slug `grizzly` v2.4.2; install `@yieldingbear/grizzly` / `clawhub install grizzly`; keys `grizzly_live_sk_` (+ legacy `yb_live_sk_`); `yb.sh set-routing auto`; router `yieldingbear/grizzly-1.0g-pro` |
| Product | Base **only** `https://yieldingbear.com/api/v1` |

## Field matrix
| Thing | Repo 2.2.0 | Live listing 2.4.2 | Canonical (WS1) |
|-------|------------|--------------------|-----------------|
| ClawHub slug / name | yieldingbear | grizzly (display Grizzly) | **grizzly** |
| Install | clawhub install yieldingbear | clawhub install grizzly / openclaw skills install @yieldingbear/grizzly | match live; docs alias yieldingbear |
| Key env | YIELDINGBEAR_API_KEY | YIELDINGBEAR_API_KEY | + legacy **YB_API_KEY** |
| Key prefix | yb_live_sk_ | grizzly_live_sk_ + yb_live_sk_ | both (+ yb_test_sk_ ok) |
| Default model | yieldingbear/grizzly-1.0g-pro | same | same |
| CLI routing | set-model only | set-routing auto\|manual + set-model | set-routing default auto; set-model pin |
| Base URL | /api/v1 | /api/v1 | /api/v1 only |

## Live API (verified)
- `GET /api/v1/models` → `{object,data,yieldingbear.data[]}` where `yieldingbear.data[]` has `id,is_free,pricing.{input,output}_per_mtok_usd,display_name,is_virtual`
- Free list: **never hardcode** — use `yieldingbear.data[is_free=true]`
- Router id in catalog: **only** `yieldingbear/grizzly-1.0g-pro`
- `GET /api/public/routing-recommendations` → high/mid/low + router_model + modes
- `GET /api/health/grizzly-routing` → tiers high/mid/low with USD/1M + is_free
- `GET /api/v1/usage` → 401 without key (endpoint exists)
- Virtual keys mint paths → 404 — stub only later

## Hooks
| Runtime | Model-resolve hook? | Ops path |
|---------|---------------------|----------|
| OpenClaw | Yes `api.on("before_model_resolve")` → `{modelOverride?, providerOverride?}`; non-bundled needs allowConversationAccess | plugin/ companion |
| Hermes | No model-resolve hook in skill frontmatter | always-on skill + installer default model |

OpenClaw always-on skill: `metadata.openclaw.always: true`.

## Live package gaps vs mandate
1. No `yb.sh why` (only explain) — explain lacks live $/1M from health
2. `load_key` ignores `YB_API_KEY`
3. `set-routing`/`set-model` sync always sent routing_tier `auto`
4. Doctor lacks free smoke + fake `(Free)` warn
5. Repo still 2.2.0 yieldingbear — split from live
6. No grizzly-ops / plugin yet

## WS1 file touch list
- SKILL.md, scripts/yb.sh, scripts/install.sh, CHANGELOG.md, WS0-MISMATCH.md
