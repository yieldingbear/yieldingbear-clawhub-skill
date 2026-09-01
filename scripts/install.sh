#!/usr/bin/env bash
# Yielding Bear — agent installer (2026.09.01) — ClawHub skill bundle
# Usage: curl -fsSL https://yieldingbear.com/install.sh | bash
#
# Clean two-step setup:
#   1/2  API key
#   2/2  default model
# No JSON dumps. No mapfile. Reads interactive input from /dev/tty when piped.

set -euo pipefail

VERSION="2026.09.01"
BASE_URL="${YIELDINGBEAR_BASE_URL:-https://yieldingbear.com/api/v1}"
SITE_URL="https://yieldingbear.com"
DASHBOARD_URL="${SITE_URL}/dashboard?tab=developer"
DEFAULT_MODEL="yieldingbear/grizzly-1.0g"

# ── UI (TTY only) ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; RESET=""
fi
say()  { printf '%b\n' "$*"; }
ok()   { say "${GREEN}OK${RESET}  $*"; }
warn() { say "${YELLOW}!${RESET}   $*"; }
die()  { say "${RED}ERR${RESET} $*" >&2; exit 1; }

# Always prompt on a real terminal when piped via curl | bash
read_tty() {
  # usage: read_tty VAR [-s]
  local __var="$1"; shift || true
  local __flags=()
  if [[ "${1:-}" == "-s" ]]; then
    __flags=(-s)
    shift || true
  fi
  if [[ -r /dev/tty ]]; then
    # shellcheck disable=SC2162
    read "${__flags[@]}" -r "$__var" < /dev/tty
  else
    # shellcheck disable=SC2162
    read "${__flags[@]}" -r "$__var"
  fi
}

hr() { say "${DIM}----------------------------------------------${RESET}"; }

# ── Runtime paths ──────────────────────────────────────────────────────────
AGENT="shell"
if [[ -n "${HERMES_HOME:-}" || -d "${HOME}/.hermes" ]]; then
  AGENT="hermes"
  ROOT="${HERMES_HOME:-$HOME/.hermes}"
  SECRETS_DIR="$ROOT/secrets"
  CONFIG_DIR="$ROOT/config"
elif [[ -n "${OPENCLAW_HOME:-}" || -d "${HOME}/.openclaw" ]]; then
  AGENT="openclaw"
  ROOT="${OPENCLAW_HOME:-$HOME/.openclaw}"
  SECRETS_DIR="$ROOT/secrets"
  CONFIG_DIR="$ROOT/config"
else
  SECRETS_DIR="$HOME/.config/yieldingbear/secrets"
  CONFIG_DIR="$HOME/.config/yieldingbear"
fi

mkdir -p "$SECRETS_DIR" "$CONFIG_DIR" 2>/dev/null || die "Cannot create $SECRETS_DIR or $CONFIG_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true
chmod 700 "$CONFIG_DIR" 2>/dev/null || true

KEY_FILE="$SECRETS_DIR/yieldingbear-token"
CONFIG_FILE="$CONFIG_DIR/yieldingbear.json"
ENV_FILE="$CONFIG_DIR/env.sh"

clear_partial() {
  rm -f "$CONFIG_FILE" "$ENV_FILE" 2>/dev/null || true
}

# ── Banner ─────────────────────────────────────────────────────────────────
hr
say "${BOLD}Yielding Bear setup${RESET}  ${DIM}v${VERSION}${RESET}"
say "${DIM}Runtime: ${AGENT}${RESET}"
hr
say ""
say "Get a key:  ${CYAN}${DASHBOARD_URL}${RESET}"
say ""

# ── Step 1/2 — API key ─────────────────────────────────────────────────────
say "${BOLD}Step 1/2 — API key${RESET}"
api_key="${YIELDINGBEAR_API_KEY:-}"

if [[ -z "$api_key" && -s "$KEY_FILE" ]]; then
  api_key="$(tr -d '[:space:]' < "$KEY_FILE" 2>/dev/null || true)"
  if [[ -n "$api_key" ]]; then
    ok "Found existing key file"
  fi
fi

if [[ -z "$api_key" ]]; then
  printf '%b' "Paste API key (yb_live_sk_...): "
  read_tty api_key -s
  echo
  api_key="$(printf '%s' "$api_key" | tr -d '[:space:]')"
fi

if [[ -z "$api_key" ]]; then
  die "No API key. Create one at ${DASHBOARD_URL}"
fi
if [[ "$api_key" != yb_live_sk_* ]]; then
  die "Key must start with yb_live_sk_"
fi

# Validate key with a tiny free/default chat call (never dump response JSON)
say "${DIM}Checking key…${RESET}"
http_code="$(
  curl -sS -o /tmp/yb-install-validate.json -w '%{http_code}' \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${DEFAULT_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":4}" \
    2>/dev/null || echo "000"
)"
case "$http_code" in
  200|201)
    ok "Key works"
    ;;
  401|403)
    clear_partial
    rm -f /tmp/yb-install-validate.json 2>/dev/null || true
    die "Key rejected (HTTP ${http_code}). Create a new key at ${DASHBOARD_URL}"
    ;;
  402)
    # Paid-only balance issue on default model — still accept key, try free later
    warn "Key accepted but wallet may need credits for paid models (HTTP 402)."
    ;;
  *)
    # Retry against a known free model if default failed for other reasons
    free_try="$(
      curl -sS -o /tmp/yb-install-validate.json -w '%{http_code}' \
        -X POST "${BASE_URL}/chat/completions" \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d '{"model":"liquid/lfm-2.5-2.6b","messages":[{"role":"user","content":"ping"}],"max_tokens":4}' \
        2>/dev/null || echo "000"
    )"
    if [[ "$free_try" != "200" && "$free_try" != "201" && "$free_try" != "402" ]]; then
      clear_partial
      rm -f /tmp/yb-install-validate.json 2>/dev/null || true
      die "Could not validate key (HTTP ${http_code}). Check ${SITE_URL}/docs"
    fi
    ok "Key works"
    ;;
esac
rm -f /tmp/yb-install-validate.json 2>/dev/null || true

# Persist key only after validation
printf '%s\n' "$api_key" > "$KEY_FILE"
chmod 600 "$KEY_FILE" 2>/dev/null || true
ok "Saved key → ${KEY_FILE}"
say ""

# ── Step 2/2 — Model ───────────────────────────────────────────────────────
say "${BOLD}Step 2/2 — Default model${RESET}"
say "${DIM}Fetching catalog…${RESET}"

models_body="$(
  curl -sS -H "Accept: application/json" \
    "${SITE_URL}/api/v1/models" 2>/dev/null || true
)"

# Build a short menu without dumping JSON. Prefer python3; fall back to defaults.
MENU_FILE="$(mktemp -t yb-models.XXXXXX 2>/dev/null || echo /tmp/yb-models-$$.txt)"
trap 'rm -f "$MENU_FILE" 2>/dev/null || true' EXIT

build_menu_py() {
  python3 - "$MENU_FILE" <<'PY' || return 1
import json, sys
out_path = sys.argv[1]
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.exit(1)
rows = data.get("yieldingbear", {}).get("data") or data.get("data") or []
if not isinstance(rows, list):
    sys.exit(1)

def score(m):
    mid = str(m.get("id") or "")
    virt = 0 if (m.get("is_virtual") is True or mid.startswith("yieldingbear/")) else 1
    free = 0 if m.get("is_free") is True else 1
    return (virt, free, mid)

rows = [m for m in rows if m.get("id")]
rows.sort(key=score)
# Keep menu short and scannable
rows = rows[:16]
with open(out_path, "w", encoding="utf-8") as f:
    for m in rows:
        mid = m.get("id") or ""
        free = "free" if m.get("is_free") is True else "paid"
        virt = "router" if (m.get("is_virtual") is True or str(mid).startswith("yieldingbear/")) else ""
        tag = free if not virt else f"{virt},{free}"
        f.write(f"{mid}\t{tag}\n")
print(len(rows))
PY
}

menu_count=0
if command -v python3 >/dev/null 2>&1 && [[ -n "$models_body" ]]; then
  menu_count="$(printf '%s' "$models_body" | build_menu_py || echo 0)"
fi

chosen_model="$DEFAULT_MODEL"
if [[ "${menu_count:-0}" =~ ^[0-9]+$ ]] && [[ "$menu_count" -gt 0 && -s "$MENU_FILE" ]]; then
  i=0
  while IFS=$'\t' read -r mid tag; do
    i=$((i + 1))
    mark=""
    if [[ "$mid" == "$DEFAULT_MODEL" ]]; then
      mark=" ${GREEN}(default)${RESET}"
    fi
    printf '  %2d) %s  %b%s%b%b\n' "$i" "$mid" "${DIM}" "[$tag]" "${RESET}" "$mark"
  done < "$MENU_FILE"
  say "   0) keep default  ${BOLD}${DEFAULT_MODEL}${RESET}"
  say "   c) type a custom model id"
  say ""
  printf '%b' "Pick model number ${DIM}[0]${RESET}: "
  choice=""
  read_tty choice
  choice="$(printf '%s' "$choice" | tr -d '[:space:]')"

  case "$choice" in
    ""|0|d|D)
      chosen_model="$DEFAULT_MODEL"
      ;;
    c|C)
      printf '%b' "model id: "
      custom=""
      read_tty custom
      custom="$(printf '%s' "$custom" | tr -d '[:space:]')"
      if [[ -n "$custom" ]]; then
        chosen_model="$custom"
      fi
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]]; then
        line="$(sed -n "${choice}p" "$MENU_FILE" 2>/dev/null || true)"
        mid="${line%%$'\t'*}"
        if [[ -n "$mid" ]]; then
          chosen_model="$mid"
        else
          warn "Invalid pick — using default."
          chosen_model="$DEFAULT_MODEL"
        fi
      else
        # Treat free-typed id as the model
        chosen_model="$choice"
      fi
      ;;
  esac
else
  say "${DIM}Catalog unavailable offline — using ${DEFAULT_MODEL}${RESET}"
  printf '%b' "Model id ${DIM}[${DEFAULT_MODEL}]${RESET}: "
  typed=""
  read_tty typed
  typed="$(printf '%s' "$typed" | tr -d '[:space:]')"
  if [[ -n "$typed" ]]; then
    chosen_model="$typed"
  fi
fi

ok "Model: ${BOLD}${chosen_model}${RESET}"

# ── Write config (only after both steps succeed) ───────────────────────────
umask 077
cat > "$CONFIG_FILE" <<EOF
{
  "version": "${VERSION}",
  "base_url": "${BASE_URL}",
  "default_model": "${chosen_model}",
  "fallback_models": ["yieldingbear/grizzly-1.0g", "liquid/lfm-2.5-2.6b", "nvidia/nemotron-3.5-lightning"],
  "key_file": "${KEY_FILE}",
  "runtime": "${AGENT}"
}
EOF
chmod 600 "$CONFIG_FILE" 2>/dev/null || true

cat > "$ENV_FILE" <<EOF
# Yielding Bear — generated by install.sh ${VERSION}
export YIELDINGBEAR_API_KEY="\$(cat '${KEY_FILE}' 2>/dev/null)"
export YIELDINGBEAR_BASE_URL="${BASE_URL}"
export YIELDINGBEAR_DEFAULT_MODEL="${chosen_model}"
EOF
chmod 600 "$ENV_FILE" 2>/dev/null || true

# Optional SDK vendor (quiet — no spam if missing runtimes)
SDK_DIR="${HOME}/.yieldingbear/lib"
mkdir -p "$SDK_DIR" 2>/dev/null || true
if command -v python3 >/dev/null 2>&1; then
  curl -fsSL "${SITE_URL}/sdk/yieldingbear.py" -o "${SDK_DIR}/yieldingbear.py" 2>/dev/null || true
fi
if command -v node >/dev/null 2>&1; then
  curl -fsSL "${SITE_URL}/sdk/yieldingbear.mjs" -o "${SDK_DIR}/yieldingbear.mjs" 2>/dev/null || true
fi

# Quiet smoke test (one line reply max)
say "${DIM}Smoke test…${RESET}"
smoke_code="$(
  curl -sS -o /tmp/yb-install-smoke.json -w '%{http_code}' \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${chosen_model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ready\"}],\"max_tokens\":8}" \
    2>/dev/null || echo "000"
)"
if [[ "$smoke_code" == "200" || "$smoke_code" == "201" ]]; then
  reply=""
  if command -v python3 >/dev/null 2>&1; then
    reply="$(python3 - <<'PY' 2>/dev/null || true
import json
try:
    j=json.load(open("/tmp/yb-install-smoke.json"))
    c=(j.get("choices") or [{}])[0]
    t=(c.get("message") or {}).get("content") or ""
    if isinstance(t, list):
        t="".join(str(x) for x in t)
    print((t or "").strip().replace("\n"," ")[:80])
except Exception:
    pass
PY
)"
  fi
  if [[ -n "$reply" ]]; then
    ok "Smoke: ${reply}"
  else
    ok "Smoke: HTTP ${smoke_code}"
  fi
elif [[ "$smoke_code" == "402" ]]; then
  warn "Model needs credits (HTTP 402). Key + config are saved — add credits or pick a free model."
else
  warn "Smoke HTTP ${smoke_code} — config saved; try again from the dashboard if needed."
fi
rm -f /tmp/yb-install-smoke.json 2>/dev/null || true

say ""
hr
say "${BOLD}Ready${RESET}"
say "  key     ${KEY_FILE}"
say "  config  ${CONFIG_FILE}"
say "  model   ${chosen_model}"
say ""
say "Load env:  ${CYAN}source ${ENV_FILE}${RESET}"
say "Docs:      ${CYAN}${SITE_URL}/docs${RESET}"
hr
