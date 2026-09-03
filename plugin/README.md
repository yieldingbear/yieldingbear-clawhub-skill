# Yielding Bear — OpenClaw plugin

Routes OpenClaw turns through Yielding Bear Auto (`yieldingbear/grizzly-1.0g-pro`) and optional high / mid / free rails via `before_model_resolve`.

## Install (ClawHub)

```bash
openclaw plugins install clawhub:@yieldingbear/yieldingbear
openclaw plugins enable yieldingbear
openclaw gateway restart
```

## Local link (dev)

```bash
openclaw plugins install --link ./plugin --force
openclaw plugins enable yieldingbear
```

In `openclaw.json`:

```json
{
  "plugins": {
    "entries": {
      "yieldingbear": {
        "enabled": true,
        "hooks": { "allowConversationAccess": true }
      }
    }
  }
}
```

## Behavior

- Default override: `modelOverride: yieldingbear/grizzly-1.0g-pro` + provider `yieldingbear`.
- If ops config has a rail pin / skill map: map `high|mid|free` to live ids from `/api/health/grizzly-routing` (cached ~60s).
- Fail closed to **Auto router**, never bare Opus / `claude-*` without provider prefix.
- Decisions: `~/.openclaw/config/yieldingbear/decisions.jsonl`

## Product

- Gateway: `https://yieldingbear.com/api/v1`
- Keys: `YIELDINGBEAR_API_KEY` (`grizzly_live_sk_…` / legacy `yb_live_sk_…`)
- Dashboard: https://yieldingbear.com/dashboard

## Tests

```bash
npm test
```

Network is not required for unit tests.
