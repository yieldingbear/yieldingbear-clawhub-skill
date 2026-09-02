#!/usr/bin/env bash
# Yielding Bear — agent installer (2.5.0) — ClawHub skill bundle
# Usage: curl -fsSL https://yieldingbear.com/install.sh | bash
#
# Walkthrough:
#   0) Account (signup + optional $10 off Pro × first 3 months via CLI offer)
#   1) API key
#   2) Plan fork: Pro | credits | free models
#   3) Routing mode: Auto-select (Grizzly) or Manual pin (+ YB recs)
#   4) Smoke + next commands (yb.sh doctor / models / set-routing)
#
# No JSON dumps. Reads interactive input from /dev/tty when piped.

set -euo pipefail

VERSION="2.5.0"
BASE_URL="${YIELDINGBEAR_BASE_URL:-https://yieldingbear.com/api/v1}"
SITE_URL="${YIELDINGBEAR_SITE_URL:-https://yieldingbear.com}"
DASHBOARD_URL="${SITE_URL}/dashboard?tab=developer"
PRICING_URL="${SITE_URL}/pricing"
CREDITS_URL="${SITE_URL}/dashboard?tab=overview"
OFFER_URL="${SITE_URL}/offer/cli10x3?next=/signup%3Fnext%3D%2Fpricing"
DEFAULT_MODEL="yieldingbear/grizzly-1.0g-pro"
FREE_FALLBACK="liquid/lfm-2.5-2.6b"

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

read_tty() {
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

open_url() {
  local u="$1"
  if command -v open >/dev/null 2>&1; then
    open "$u" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$u" >/dev/null 2>&1 || true
  fi
}

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

# Prefer skill-bundled yb.sh when present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
YB_SH=""
for cand in \
  "${SCRIPT_DIR}/yb.sh" \
  "${HOME}/.openclaw/skills/yieldingbear/scripts/yb.sh" \
  "${HOME}/.hermes/skills/openclaw-imports/yieldingbear/scripts/yb.sh" \
  "${HOME}/.yieldingbear/bin/yb.sh"
do
  if [[ -x "$cand" ]]; then YB_SH="$cand"; break; fi
  if [[ -f "$cand" ]]; then YB_SH="$cand"; break; fi
done

clear_partial() {
  rm -f "$CONFIG_FILE" "$ENV_FILE" 2>/dev/null || true
}

# ── Banner ─────────────────────────────────────────────────────────────────
hr
say "${BOLD}Yielding Bear setup${RESET}  ${DIM}v${VERSION}${RESET}"
say "${DIM}Runtime: ${AGENT} · One API · 100+ LLMs · Smart Routing${RESET}"
hr
say ""
say "Grizzly picks ${BOLD}high${RESET} (frontier reasoners), ${BOLD}mid${RESET} (fast/cheap), and ${BOLD}free${RESET}"
say "per prompt. Optional semantic cache + bandit self-improve when enabled."
say ""

# ── Step 0 — Account ───────────────────────────────────────────────────────
say "${BOLD}Step 0/4 — Account${RESET}"
say "  Sign up (browser): ${CYAN}${OFFER_URL}${RESET}"
say "  ${DIM}CLI/ClawHub offer: \$10 off Grizzly Pro for first 3 months (\$89 then \$99).${RESET}"
say "  ${DIM}Referral links use a separate \$20 first-month deal — not stacked.${RESET}"
say ""
if [[ -z "${YIELDINGBEAR_API_KEY:-}" && ! -s "$KEY_FILE" ]]; then
  printf '%b' "Open signup in browser now? [Y/n]: "
  open_ans=""
  read_tty open_ans || true
  open_ans="$(printf '%s' "${open_ans:-Y}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [[ -z "$open_ans" || "$open_ans" == "y" || "$open_ans" == "yes" ]]; then
    open_url "$OFFER_URL"
    ok "Opened signup (offer cookie set for checkout)"
  fi
fi
say ""

# ── Step 1 — API key ───────────────────────────────────────────────────────
say "${BOLD}Step 1/4 — API key${RESET}"
say "Create/copy key: ${CYAN}${DASHBOARD_URL}${RESET}"
api_key="${YIELDINGBEAR_API_KEY:-${YB_API_KEY:-}}"

if [[ -z "$api_key" && -s "$KEY_FILE" ]]; then
  api_key="$(tr -d '[:space:]' < "$KEY_FILE" 2>/dev/null || true)"
  if [[ -n "$api_key" ]]; then
    ok "Found existing key file"
  fi
fi

if [[ -z "$api_key" ]]; then
  printf '%b' "Paste API key (grizzly_live_sk_... or yb_live_sk_...): "
  read_tty api_key -s
  echo
  api_key="$(printf '%s' "$api_key" | tr -d '[:space:]')"
fi

if [[ -z "$api_key" ]]; then
  die "No API key. Create one at ${DASHBOARD_URL}"
fi
if [[ "$api_key" != grizzly_live_sk_* && "$api_key" != yb_live_sk_* && "$api_key" != yb_test_sk_* ]]; then
  die "Key must start with grizzly_live_sk_ (or legacy yb_live_sk_)"
fi

say "${DIM}Checking key…${RESET}"
http_code="$(
  curl -sS -o /tmp/yb-install-validate.json -w '%{http_code}' \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${FREE_FALLBACK}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":4}" \
    2>/dev/null || echo "000"
)"
case "$http_code" in
  200|201)
    ok "Key works (free model smoke)"
    ;;
  401|403)
    clear_partial
    rm -f /tmp/yb-install-validate.json 2>/dev/null || true
    die "Key rejected (HTTP ${http_code}). Create a new key at ${DASHBOARD_URL}"
    ;;
  402)
    warn "Key accepted but wallet may need credits for paid models (HTTP 402)."
    ;;
  *)
    free_try="$(
      curl -sS -o /tmp/yb-install-validate.json -w '%{http_code}' \
        -X POST "${BASE_URL}/chat/completions" \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${DEFAULT_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":4}" \
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

printf '%s\n' "$api_key" > "$KEY_FILE"
chmod 600 "$KEY_FILE" 2>/dev/null || true
ok "Saved key → ${KEY_FILE}"
say ""

# ── Step 2 — Plan fork ─────────────────────────────────────────────────────
say "${BOLD}Step 2/4 — Plan${RESET}"
say "  1) Grizzly Pro  ${DIM}\$10 off first 3 months (\$89→\$99) via CLI offer${RESET}"
say "  2) Buy credits  ${DIM}pay-as-you-go from \$10${RESET}"
say "  3) Stay free    ${DIM}true \$0 models only — default free router path${RESET}"
say "  0) Skip (decide later in dashboard)"
say ""
printf '%b' "Choose ${DIM}[3]${RESET}: "
plan_choice=""
read_tty plan_choice || true
plan_choice="$(printf '%s' "${plan_choice:-3}" | tr -d '[:space:]')"
case "$plan_choice" in
  1|p|P|pro|PRO)
    say "Opening Pro checkout path (offer cookie + pricing)…"
    open_url "${SITE_URL}/offer/cli10x3?next=/pricing"
    ok "Browser → pricing. After login, Start Grizzly Pro applies \$10×3 when eligible."
    say "${DIM}If you used a referral link, referral \$20-once wins (not stacked).${RESET}"
    ;;
  2|c|C|credits)
    open_url "$CREDITS_URL"
    ok "Browser → dashboard credits"
    ;;
  0|s|S|skip)
    say "${DIM}Skipped plan step.${RESET}"
    ;;
  *)
    ok "Free path — pick a free model next (or keep Grizzly for Pro tiers later)"
    ;;
esac
say ""

# ── Step 3 — Routing mode + model ─────────────────────────────────────────
say "${BOLD}Step 3/4 — Routing mode${RESET}"
say "  ${DIM}Same toggle as Dashboard → Active Model.${RESET}"
say ""

# Live recommendations (public) — same source as dashboard chips
REC_HIGH="" REC_MID="" REC_LOW="" REC_ROUTER="yieldingbear/grizzly-1.0g-pro"
rec_json="$(curl -sS -m 15 -H 'Accept: application/json' \
  "${SITE_URL}/api/public/routing-recommendations" 2>/dev/null || true)"
if command -v python3 >/dev/null 2>&1 && [[ -n "$rec_json" ]]; then
  eval "$(
    printf '%s' "$rec_json" | python3 -c '
import json,sys,shlex
try:
 j=json.load(sys.stdin)
except Exception:
 sys.exit(0)
def q(s): return shlex.quote(str(s or ""))
print("REC_HIGH="+q(j.get("high")))
print("REC_MID="+q(j.get("mid")))
print("REC_LOW="+q(j.get("low")))
print("REC_ROUTER="+q(j.get("router_model") or "yieldingbear/grizzly-1.0g-pro"))
' 2>/dev/null || true
  )"
fi
[[ -z "$REC_HIGH" ]] && REC_HIGH="anthropic/claude-sonnet-4.6"
[[ -z "$REC_MID" ]] && REC_MID="google/gemini-2.5-flash"
[[ -z "$REC_LOW" ]] && REC_LOW="nvidia/nemotron-3-nano-30b"
[[ -z "$REC_ROUTER" ]] && REC_ROUTER="yieldingbear/grizzly-1.0g-pro"

say "  Yielding Bear recommendations (live):"
say "    high  ${CYAN}${REC_HIGH}${RESET}"
say "    mid   ${CYAN}${REC_MID}${RESET}"
say "    free  ${CYAN}${REC_LOW}${RESET}  ${DIM}(true \$0 when is_free)${RESET}"
say ""
say "  1) ${BOLD}Auto-select${RESET}  ${DIM}recommended — Grizzly classifies high/mid/free per prompt${RESET}"
say "  2) ${BOLD}Manual${RESET}       ${DIM}pin a catalog model (YB chips + full library)${RESET}"
say ""

ROUTING_MODE="auto"
chosen_model="$REC_ROUTER"
if [[ -n "${YIELDINGBEAR_ROUTING_MODE:-}" ]]; then
  case "$(printf '%s' "$YIELDINGBEAR_ROUTING_MODE" | tr 'A-Z' 'a-z')" in
    manual|man|m) ROUTING_MODE="manual" ;;
    *) ROUTING_MODE="auto" ;;
  esac
  if [[ -n "${YIELDINGBEAR_DEFAULT_MODEL:-}" ]]; then
    chosen_model="$YIELDINGBEAR_DEFAULT_MODEL"
  fi
  if [[ "$ROUTING_MODE" == "auto" ]]; then
    chosen_model="$REC_ROUTER"
  fi
  ok "Non-interactive routing_mode=${ROUTING_MODE} model=${chosen_model}"
else
  printf '%b' "Routing mode ${DIM}[1=auto]${RESET}: "
  rm_choice=""
  read_tty rm_choice
  rm_choice="$(printf '%s' "$rm_choice" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  case "$rm_choice" in
    2|m|manual|man) ROUTING_MODE="manual" ;;
    *) ROUTING_MODE="auto" ;;
  esac
fi

if [[ "$ROUTING_MODE" == "auto" ]]; then
  chosen_model="$REC_ROUTER"
  ok "Auto-select → ${BOLD}${chosen_model}${RESET} (tier=auto, YB tier table)"
else
  say ""
  say "${BOLD}Manual — pick default model${RESET}"
  say "${DIM}Fetching catalog + live \$/1M…${RESET}"

  models_body="$(
    curl -sS -H "Accept: application/json" \
      "${SITE_URL}/api/v1/models" 2>/dev/null || true
  )"

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
picked = []
for m in rows:
    mid = str(m.get("id") or "")
    if m.get("is_virtual") or mid.startswith("yieldingbear/"):
        picked.append(m)
for m in rows:
    if m.get("is_free") is True and m not in picked:
        picked.append(m)
    if len(picked) >= 12:
        break
for m in rows:
    if m not in picked:
        picked.append(m)
    if len(picked) >= 18:
        break

with open(out_path, "w", encoding="utf-8") as f:
    for m in picked:
        mid = m.get("id") or ""
        free = "free" if m.get("is_free") is True else "paid"
        virt = "router" if (m.get("is_virtual") is True or str(mid).startswith("yieldingbear/")) else ""
        pr = m.get("pricing") or {}
        try:
            inp = float(pr.get("input_per_mtok_usd") or 0)
            out = float(pr.get("output_per_mtok_usd") or 0)
        except Exception:
            inp = out = 0.0
        if free == "free":
            price = "$0"
        elif virt:
            price = "routed"
        else:
            price = f"${inp:g}/${out:g} per 1M"
        tag = free if not virt else f"{virt},{free}"
        f.write(f"{mid}\t{tag}\t{price}\n")
print(len(picked))
PY
  }

  menu_count=0
  if command -v python3 >/dev/null 2>&1 && [[ -n "$models_body" ]]; then
    menu_count="$(printf '%s' "$models_body" | build_menu_py || echo 0)"
  fi

  chosen_model="$REC_ROUTER"
  say "  Recommended pins:"
  say "    r) router  ${REC_ROUTER}"
  say "    h) high    ${REC_HIGH}"
  say "    m) mid     ${REC_MID}"
  say "    l) free    ${REC_LOW}"
  if [[ "${menu_count:-0}" =~ ^[0-9]+$ ]] && [[ "$menu_count" -gt 0 && -s "$MENU_FILE" ]]; then
    i=0
    while IFS=$'\t' read -r mid tag price; do
      i=$((i + 1))
      printf '  %2d) %s  %b%s%b  %b%s%b\n' \
        "$i" "$mid" "${DIM}" "[$tag]" "${RESET}" "${CYAN}" "$price" "${RESET}"
    done < "$MENU_FILE"
    say "   c) type a custom model id"
    say ""
    printf '%b' "Pick ${DIM}[r=router]${RESET}: "
    choice=""
    read_tty choice
    choice="$(printf '%s' "$choice" | tr -d '[:space:]')"
    case "$choice" in
      ""|r|R|0) chosen_model="$REC_ROUTER" ;;
      h|H) chosen_model="$REC_HIGH" ;;
      m|M) chosen_model="$REC_MID" ;;
      l|L|f|F) chosen_model="$REC_LOW" ;;
      c|C)
        printf '%b' "model id: "
        custom=""; read_tty custom
        custom="$(printf '%s' "$custom" | tr -d '[:space:]')"
        [[ -n "$custom" ]] && chosen_model="$custom"
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          line="$(sed -n "${choice}p" "$MENU_FILE" 2>/dev/null || true)"
          mid="${line%%$'\t'*}"
          [[ -n "$mid" ]] && chosen_model="$mid"
        elif [[ -n "$choice" ]]; then
          chosen_model="$choice"
        fi
        ;;
    esac
  else
    say "${DIM}Catalog offline — using recommendations only${RESET}"
    printf '%b' "Model id ${DIM}[${REC_ROUTER}]${RESET}: "
    typed=""; read_tty typed
    typed="$(printf '%s' "$typed" | tr -d '[:space:]')"
    [[ -n "$typed" ]] && chosen_model="$typed"
  fi
  ok "Manual → ${BOLD}${chosen_model}${RESET}"
fi

# ── Write config ───────────────────────────────────────────────────────────
umask 077
cat > "$CONFIG_FILE" <<EOF
{
  "version": "${VERSION}",
  "base_url": "${BASE_URL}",
  "routing_mode": "${ROUTING_MODE}",
  "default_model": "${chosen_model}",
  "fallback_models": ["${REC_ROUTER}", "${REC_LOW}", "liquid/lfm-2.5-2.6b"],
  "recommended_tiers": {
    "high": "${REC_HIGH}",
    "mid": "${REC_MID}",
    "low": "${REC_LOW}"
  },
  "key_file": "${KEY_FILE}",
  "runtime": "${AGENT}",
  "signup_offer": "cli10x3"
}
EOF
chmod 600 "$CONFIG_FILE" 2>/dev/null || true

cat > "$ENV_FILE" <<EOF
# Yielding Bear — generated by install.sh ${VERSION}
export YIELDINGBEAR_API_KEY="\$(cat '${KEY_FILE}' 2>/dev/null)"
export YIELDINGBEAR_BASE_URL="${BASE_URL}"
export YIELDINGBEAR_DEFAULT_MODEL="${chosen_model}"
export YIELDINGBEAR_ROUTING_MODE="${ROUTING_MODE}"
export YIELDINGBEAR_SITE_URL="${SITE_URL}"
EOF

chmod 600 "$ENV_FILE" 2>/dev/null || true

# Sync routing prefs to account (API key) so dashboard matches install
if [[ -n "${api_key:-}" ]]; then
  _default_for_api="$chosen_model"
  _routing_tier='auto'
  if [[ "$ROUTING_MODE" == "auto" ]]; then
    _default_for_api="$REC_ROUTER"
    _routing_tier='auto'
  fi
  curl -sS -m 20 -o /tmp/yb-pref-sync.json -w '' \
    -X PUT "${SITE_URL}/api/user/default-model" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"active_default_model\":\"${_default_for_api}\",\"routing_tier\":\"${_routing_tier}\",\"tier_routes\":null,\"fallback_models\":[\"${REC_LOW}\"]}" \
    >/dev/null 2>&1 || true
fi


# Optional SDK vendor
SDK_DIR="${HOME}/.yieldingbear/lib"
BIN_DIR="${HOME}/.yieldingbear/bin"
mkdir -p "$SDK_DIR" "$BIN_DIR" 2>/dev/null || true
if command -v python3 >/dev/null 2>&1; then
  curl -fsSL "${SITE_URL}/sdk/yieldingbear.py" -o "${SDK_DIR}/yieldingbear.py" 2>/dev/null || true
fi
if command -v node >/dev/null 2>&1; then
  curl -fsSL "${SITE_URL}/sdk/yieldingbear.mjs" -o "${SDK_DIR}/yieldingbear.mjs" 2>/dev/null || true
fi
# Mirror yb.sh next to install when run from skill
if [[ -n "$YB_SH" && -f "$YB_SH" ]]; then
  cp "$YB_SH" "${BIN_DIR}/yb.sh" 2>/dev/null || true
  chmod +x "${BIN_DIR}/yb.sh" 2>/dev/null || true
fi

# ── Step 4 — Smoke ─────────────────────────────────────────────────────────
say ""
say "${BOLD}Step 4/4 — Smoke${RESET}"
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
  warn "Model needs credits/Pro (HTTP 402). Config saved — pick free (f) or add credits."
else
  warn "Smoke HTTP ${smoke_code} — config saved; try yb.sh doctor."
fi
rm -f /tmp/yb-install-smoke.json 2>/dev/null || true

say ""
hr
say "${BOLD}Ready${RESET}"
say "  key     ${KEY_FILE}"
say "  config  ${CONFIG_FILE}"
say "  mode    ${ROUTING_MODE}"
say "  model   ${chosen_model}"
say ""
say "Load env:  ${CYAN}source ${ENV_FILE}${RESET}"
if [[ -n "$YB_SH" ]]; then
  say "Doctor:    ${CYAN}bash ${YB_SH} doctor${RESET}"
  say "Models:    ${CYAN}bash ${YB_SH} models${RESET}"
  say "Mode:      ${CYAN}bash ${YB_SH} set-routing auto|manual [model]${RESET}"
  say "Switch:    ${CYAN}bash ${YB_SH} set-model <id>${RESET}"
  say "Explain:   ${CYAN}bash ${YB_SH} explain${RESET}"
else
  say "Install skill CLI: ${CYAN}clawhub install grizzly${RESET}"
  say "Then: bash ~/.openclaw/skills/yieldingbear/scripts/yb.sh doctor"
fi
say "Docs:      ${CYAN}${SITE_URL}/docs${RESET}"
say "Pricing:   ${CYAN}${PRICING_URL}${RESET}"
hr
