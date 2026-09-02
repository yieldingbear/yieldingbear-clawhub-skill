#!/usr/bin/env bash
# Offline surface checks for yb.sh (no network required for --help paths).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YB="$ROOT/scripts/yb.sh"
bash -n "$YB"
bash -n "$ROOT/scripts/install.sh"

out="$("$YB" 2>&1 || true)"
for needle in set-routing why spend receipts vk-bind doctor smoke models; do
  echo "$out" | grep -q "$needle" || { echo "FAIL usage missing $needle"; exit 1; }
done

# set-routing help
help_out="$("$YB" set-routing 2>&1 || true)"
echo "$help_out" | grep -Eqi 'auto.*manual|Usage:.*set-routing' || { echo "FAIL set-routing help: $help_out"; exit 1; }

# receipts path resolves under yieldingbear/
path="$("$YB" receipts --path)"
echo "$path" | grep -q 'yieldingbear/receipts.jsonl' || { echo "FAIL receipts path: $path"; exit 1; }

# vk-bind writes config (tmp HOME)
TMP="$(mktemp -d)"
export HERMES_HOME="$TMP/hermes"
mkdir -p "$HERMES_HOME/config" "$HERMES_HOME/secrets"
# minimal key so load_key paths exist without network commands
printf 'yb_live_sk_testkey_not_real_000000000000' > "$HERMES_HOME/secrets/yieldingbear-token"
chmod 600 "$HERMES_HOME/secrets/yieldingbear-token"
"$YB" vk-bind summarize free >/dev/null
test -f "$HERMES_HOME/config/yieldingbear/grizzly-ops.json"
grep -q '"summarize": "free"' "$HERMES_HOME/config/yieldingbear/grizzly-ops.json"

"$YB" receipts --append '{"cost_usd":0.01,"rail":"free"}' >/dev/null
test -f "$HERMES_HOME/config/yieldingbear/receipts.jsonl"
"$YB" spend --session | grep -q 'cost_usd'

# forbid bad hosts in sources
! grep -R 'https://api.yieldingbear.com' "$ROOT/SKILL.md" "$ROOT/scripts" "$ROOT/grizzly-ops" "$ROOT/plugin" 2>/dev/null || {
  echo "FAIL forbidden api host present"; exit 1;
}
! grep -RE '60-80%|75% savings|SOC2 Type II' "$ROOT/SKILL.md" "$ROOT/scripts/yb.sh" "$ROOT/grizzly-ops" 2>/dev/null || {
  echo "FAIL forbidden claims"; exit 1;
}

rm -rf "$TMP"
echo "yb_cli_smoke OK"
