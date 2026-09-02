# Grizzly Ops — OpenClaw plugin (companion)

Optional companion to the **grizzly** installer skill and **grizzly-ops** always-on skill.

Hooks `before_model_resolve` so routing actually happens (skills alone cannot sit in the turn path).

## Install

```bash
# from this repo
openclaw plugins install --link ./plugin --force
openclaw plugins enable grizzly-ops
```

In `openclaw.json`:

```json
{
  "plugins": {
    "entries": {
      "grizzly-ops": {
        "enabled": true,
        "hooks": { "allowConversationAccess": true }
      }
    }
  }
}
```

Then:

```bash
openclaw gateway restart
openclaw plugins inspect grizzly-ops --runtime --json
```

## Behavior

- Default override: `modelOverride: yieldingbear/grizzly-1.0g-pro` + provider `yieldingbear`.
- If ops config has a rail pin / skill map: map `high|mid|free` to live ids from `/api/health/grizzly-routing` (cached ~60s).
- Fail closed to **Auto router**, never bare Opus / `claude-*` without provider prefix.
- Decisions: `~/.openclaw/config/yieldingbear/decisions.jsonl`

## Hermes

Hermes has no equivalent model-resolve hook. Use installer default model + `grizzly-ops` skill instructions.

## Tests

```bash
npm test
```

Network is not required for unit tests.
