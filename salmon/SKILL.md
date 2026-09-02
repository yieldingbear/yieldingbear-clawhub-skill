---
name: Salmon
description: "Always-on Yielding Bear efficiency loop: durable prefix cache, frozen tools, compact/context discipline, session-state JSON, hot/cold archive, honest-free rails. Not an installer. Local until approved for ClawHub."
version: 1.1.0
author: Yielding Bear
license: MIT
homepage: https://yieldingbear.com
metadata:
  clawhub:
    slug: salmon
    title: Salmon
  openclaw:
    always: true
    contextInjection: continuation-skip
---

# Salmon (efficiency loop)

**Theme:** Yielding Bear catches Salmon (workflow inefficiencies), retains the nutrients (quality loop, tokens kept from mitigated spend risk), and thrives on the AI frontier by utilizing and mitigating environment resources for maximum efficiency.

Logo: `assets/salmon.png` · icon: `assets/salmon-icon.png` · site: https://yieldingbear.com/skills/salmon

Not an installer. **Grizzly** wires the key; **Salmon** teaches the agent how to spend and how to keep long sessions useful without quality cliffs.

Do **not** sell or document unbounded / 1M windows. Working-set caps only. Cost still follows rails (high / mid / free) via `yieldingbear/grizzly-1.0g-pro`.

Hermes: no model-resolve hook → follow this skill every turn + `yb.sh` + installer default model.  
OpenClaw: also install the companion `plugin/` so `before_model_resolve` cannot bypass YB rails. Set OpenClaw `contextInjection: "continuation-skip"` (not `"never"`).

## Durable prefix (never compact)

Every turn’s prompt has a **frozen prefix**, in this order:

1. Yielding Bear rail policy + default `yieldingbear/grizzly-1.0g-pro`
2. Hard user/agent constraints (identity, spend caps, “don’t…”) + active pins
3. Open files / repo paths in play (path/URL + content hash when known — **not** full bodies)
4. Full **session-state JSON** durable fields only (below) — never a prose summary
5. Frozen **tool schemas** (`tools[]`) — byte-stable for the whole session
6. Last **N** user turns **verbatim** (default N=6)

Variable user text, tool results, clocks, live ids, git status, weather, live balance, and the short plan go **after** the cache line (volatile tail / last user block). If you compact, you may only compact the **tail**.

## Cache

Prompt-cache hits require a **byte-stable prefix**. Salmon rules:

1. **Canonicalize JSON** (sorted keys, stable separators) for schemas, `tools[]`, and session-state so tool_use / schema drift does not silently miss cache.
2. **Freeze `tools[]` for the session.** Snapshot at session start; hash must not change.
   - Load extra skills as **messages** (or skill text in context) — **do not** edit the live `tools[]` list mid-session.
   - Mask availability with `tool_choice` if needed.
   - Need new tools → **new session**.
3. **Keep volatile fields below the cache line** (last user / volatile block): clocks, request ids, git status, weather, live balance, spend counters that tick every turn.
4. **Do not change model, thinking, or effort mid-session** (they sit in the cache key). Compact / heartbeat turns: thinking **off** or **low**.
5. **Optional warmup:** one `max_tokens: 0` call to write the prefix cache. Skip for notify agents. Skip if YB rejects it — **do not** bypass YB to warm another host.
6. Prefix skeleton hash flapping every turn (`yb.sh context`) → cache not hitting → doctor warning.

## Compact / context

1. After a compact, **freeze that summary** until context **actually grew**. No per-turn timestamped rewrite of the same compact blob.
2. **Never compact** system / tools / bootstrap / rail policy / pins / corrections / file lists / durable state / last-N user messages.
3. Point at files by **path or URL + hash**; do not paste full bodies into the prefix.
4. Recite a short **append-only plan** (`todo.md` style) in the **volatile tail** only.
5. **Keep failed tool errors** in the trace; **do not auto-retry** the same failed call.
6. OpenClaw: `contextInjection: "continuation-skip"` — **not** `"never"`.
7. **Independent tools in parallel**, then **one** user message with all results. Sequential only when there are side effects or true data dependencies.
8. **Prune tool dumps only after cache TTL.** Do not trim the warm prefix while the provider cache is still hot.
9. Hot vs cold budgets still apply (see below). Moving tail → cold is allowed; deleting originals is not.

## Session-state JSON

Path (next to receipts):

- Hermes: `~/.hermes/config/yieldingbear/grizzly-ops-state.json`
- OpenClaw: `~/.openclaw/config/yieldingbear/grizzly-ops-state.json`

Re-inject durable fields every turn (canonical JSON). Update after each turn. Schema:

```json
{
  "goal": "",
  "pins": [{"text": "", "until": "ISO-8601", "source": "user-correction|policy"}],
  "files": [],
  "decisions": [],
  "corrections": [],
  "spend_session_usd": 0,
  "hot_window_tokens": 0
}
```

- **Prefix (durable):** `goal`, `pins`, `files`, `decisions`, `corrections` — sorted-key JSON.
- **Volatile tail:** `spend_session_usd`, `hot_window_tokens`, plus clocks / live balance / git / weather / short plan.

Pins include promote-on-correction items. Decisions are one-liners (“use /api/v1”, “do not publish”). **Never** replace this file with a prose summary.

## Two budgets: hot vs cold

Configurable in `salmon.json` (see `salmon.example.json`):

| Rail | Default hot cap (tokens, working-set) |
|------|----------------------------------------|
| free | 16k |
| mid  | 32k |
| high | 64k |

These are working-set caps, **not** model marketing windows. Do not invent a 1M product claim.

- **Hot:** current skill + prefix + last N turns + recent tool results (truncated).
- **Cold:** older turns as pointers on disk: `archive/turn-<id>.json` with `{id, ts, role, skill, rail, text, tool_ids}`. **Full original text stays on disk.**

When hot would exceed the cap: move oldest **tail** turns to cold. **Never** move the prefix or durable state JSON.

## Retrieve original — don’t trust compact

If a later hard step needs an old turn (error, constraint, file contents):

1. Search cold archive locally (`yb.sh archive --grep`) — free.
2. Splice the **original** chunk into hot on mid/free.
3. Only if retrieve fails: one-line pointer (“see turn 18”).
4. If retrieved bits disagree with any leftover summary and `speculative_escalate` is true, one high retry via YB. Default **`speculative_escalate: false`**.

Do **not** irreversibly summarize cold turns into a paragraph and delete the original.

## Compact only junk (tail)

Allowed to drop/hard-truncate from the tail **after cache TTL** (or when clearly past warm prefix):

- HTML, markdown dumps, base64, screenshots-as-text
- Repeated tool JSON
- Stack traces beyond first/last 30 lines

**Never** compact: system/rail policy, tools schemas, bootstrap, pins, corrections, file lists, durable state, last N user messages.

## Rails (cost)

- Default: all LLM calls through Yielding Bear; model `yieldingbear/grizzly-1.0g-pro` unless pin/policy says otherwise.
- Classify before a turn: **high** (hard review, security, multi-file refactor, vision with images) · **mid** (implement, search, draft) · **free** (ok/thanks/notify/format/summarize/triage/list models).
- Honest-free first: `yb.sh models --free` (live). No hardcoded free list.
- Before a paid pin: `yb.sh why` and state high/mid/free $/1M from live health — or say prices unavailable.
- **429 → backoff; do not upgrade rail; do not escalate model.** Free is 60 RPM.
- Promote-on-correction → pin high for ~7 days in state.pins.
- Receipts: append jsonl when API returns cost/routing fields; omit missing fields — never fake.
- Burn-down thresholds live in config (warn / demote / hard-stop); pinned-high exempts one turn not the session.

## Gateway (log, don’t fake)

- All completions go through **Yielding Bear** (`https://yieldingbear.com/api/v1`). Do **not** bypass YB to talk to a provider directly “for cache.”
- YB **should** forward `cache_control` / thinking and return `cached_tokens` (and related usage) when the upstream provides them.
- If markers are stripped or `cached_tokens` is missing when expected: **log it** (receipts / doctor / session note). Do not invent cache hit stats. Do not open a side channel around YB.
- Optional `max_tokens: 0` warmup is still a YB call; if YB rejects, skip warmup.

## CLI

```bash
yb.sh context              # hot tokens, cold turn count, prefix hash, tools freeze
yb.sh pin "…"              # add pin to state
yb.sh archive --grep PAT   # raw original turns (not summaries)
yb.sh spend | receipts | why | models --free | set-routing
```

Prefix skeleton hash changing every turn → cache not hitting → treat as doctor warning.

## Do not

- Semantic cache on agent loops (turn-to-turn agent state is not a semantic-cache key)
- Timestamps / clocks / live balance / git status in the **prefix**
- Mutating `tools[]` mid-session (skills load as messages; new tools → new session)
- Prune tool dumps **during** cache TTL while the prefix is still warm
- Compact the prefix (system / tools / bootstrap / durable state / last-N user)
- Delete archived originals after compact
- Escalate model or rail on **429**
- Put savings % (or ARR / SOC2 / user-count) claims in this skill
- Raise model max_tokens / context as a substitute for this design
- Summarize the whole session on free “to save money”
- Put tool dumps in the prefix
- Publish this skill to ClawHub until Laurence says **publish**
