#!/usr/bin/env bash
# Yielding Bear — doctor/status/models/smoke/set-model/explain CLI
# Usage: yb.sh <cmd> …
set -euo pipefail

SITE_URL="${YIELDINGBEAR_SITE_URL:-https://yieldingbear.com}"
BASE_URL="${YIELDINGBEAR_BASE_URL:-${SITE_URL}/api/v1}"
VERSION="2.2.0"

resolve_paths() {
  if [[ -n "${HERMES_HOME:-}" || -d "${HOME}/.hermes" ]]; then
    ROOT="${HERMES_HOME:-$HOME/.hermes}"
    RUNTIME=hermes
  elif [[ -n "${OPENCLAW_HOME:-}" || -d "${HOME}/.openclaw" ]]; then
    ROOT="${OPENCLAW_HOME:-$HOME/.openclaw}"
    RUNTIME=openclaw
  else
    ROOT="${HOME}/.config/yieldingbear"
    RUNTIME=shell
  fi
  if [[ "$RUNTIME" == "shell" ]]; then
    KEY_FILE="${ROOT}/secrets/yieldingbear-token"
    CONFIG_FILE="${ROOT}/yieldingbear.json"
    ENV_FILE="${ROOT}/env.sh"
  else
    KEY_FILE="${ROOT}/secrets/yieldingbear-token"
    CONFIG_FILE="${ROOT}/config/yieldingbear.json"
    ENV_FILE="${ROOT}/config/env.sh"
  fi
}

load_key() {
  resolve_paths
  if [[ -n "${YIELDINGBEAR_API_KEY:-}" ]]; then
    KEY="$YIELDINGBEAR_API_KEY"
  elif [[ -s "$KEY_FILE" ]]; then
    KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
  else
    KEY=""
  fi
}

cmd_status() {
  resolve_paths
  load_key
  echo "Yielding Bear CLI  v${VERSION}"
  echo "  runtime:  ${RUNTIME}"
  echo "  base:     ${BASE_URL}"
  echo "  key file: ${KEY_FILE}"
  if [[ -n "$KEY" ]]; then
    echo "  key:      ${KEY:0:12}… (${#KEY} chars)"
  else
    echo "  key:      NOT SET"
  fi
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "  config:   $CONFIG_FILE"
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$CONFIG_FILE" <<'PY' 2>/dev/null || true
import json, sys
c = json.load(open(sys.argv[1]))
print("  model:   ", c.get("default_model") or "(none)")
print("  cfg ver: ", c.get("version") or "(none)")
fb = c.get("fallback_models") or []
print("  fallback:", ", ".join(fb) if fb else "(none)")
print("  offer:   ", c.get("signup_offer") or "(none)")
PY
    fi
  else
    echo "  config:   (missing — run install)"
  fi
}

cmd_doctor() {
  cmd_status
  echo ""
  echo "Checks:"
  code="$(curl -sS -o /tmp/yb-doc-models.json -w '%{http_code}' -m 20 \
    -H 'Accept: application/json' "${SITE_URL}/api/v1/models" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    echo "  OK  GET /api/v1/models ($code)"
    if command -v python3 >/dev/null 2>&1; then
      python3 <<'PY' 2>/dev/null || true
import json
j = json.load(open("/tmp/yb-doc-models.json"))
rows = j.get("yieldingbear", {}).get("data") or j.get("data") or []
free = [m for m in rows if m.get("is_free") is True]
routers = [m for m in rows if m.get("is_virtual") or str(m.get("id","")).startswith("yieldingbear/")]
paid_free_name = [
    m for m in rows
    if m.get("is_free") is not True
    and "(Free)" in str(m.get("name") or m.get("display_name") or "")
]
print(f"  OK  catalog rows={len(rows)} free={len(free)} routers={len(routers)}")
if paid_free_name:
    ids = ", ".join(m.get("id", "?") for m in paid_free_name[:8])
    print("  WARN display '(Free)' on non-free:", ids)
PY
    fi
  else
    echo "  FAIL GET /api/v1/models HTTP $code"
  fi

  # Routing health (public)
  rcode="$(curl -sS -o /tmp/yb-doc-route.json -w '%{http_code}' -m 15 \
    -H 'Accept: application/json' "${SITE_URL}/api/health/grizzly-routing" 2>/dev/null || echo 000)"
  if [[ "$rcode" == "200" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 <<'PY' 2>/dev/null || true
import json
j=json.load(open("/tmp/yb-doc-route.json"))
ok = j.get("ok")
tiers = j.get("tiers") or {}
def mid(t):
    x = tiers.get(t) or {}
    return x.get("model") or "?"
print(f"  OK  grizzly-routing ok={ok} high={mid('high')} mid={mid('mid')} low={mid('low')}")
for t in ("high","mid","low"):
    x = tiers.get(t) or {}
    if x:
        print(f"       {t}: free={x.get('is_free')} in={x.get('input_per_mtok_usd')} out={x.get('output_per_mtok_usd')} ok={x.get('ok')}")
PY
    else
      echo "  OK  GET /api/health/grizzly-routing ($rcode)"
    fi
  else
    echo "  WARN routing health HTTP $rcode (non-blocking)"
  fi

  load_key
  if [[ -z "$KEY" ]]; then
    echo "  SKIP chat (no API key) — set YIELDINGBEAR_API_KEY or run install"
    rm -f /tmp/yb-doc-models.json /tmp/yb-doc-route.json 2>/dev/null || true
    return 0
  fi
  free_model="liquid/lfm-2.5-2.6b"
  code="$(curl -sS -o /tmp/yb-doc-chat.json -w '%{http_code}' -m 45 \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${free_model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":4}" \
    2>/dev/null || echo 000)"
  case "$code" in
    200|201) echo "  OK  chat free model ${free_model} ($code)" ;;
    401|403) echo "  FAIL key rejected ($code)" ;;
    402) echo "  WARN wallet/credits ($code)" ;;
    502) echo "  FAIL upstream gateway ($code) — LiteLLM/proxy degraded; key+config may still be valid" ;;
    *) echo "  WARN chat HTTP $code" ;;
  esac
  rm -f /tmp/yb-doc-models.json /tmp/yb-doc-chat.json /tmp/yb-doc-route.json 2>/dev/null || true
}

cmd_models() {
  free_only=0
  paid_only=0
  routers_only=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --free) free_only=1 ;;
      --paid) paid_only=1 ;;
      --routers) routers_only=1 ;;
      *) ;;
    esac
    shift || true
  done
  tmp="$(mktemp -t yb-models.XXXXXX 2>/dev/null || echo /tmp/yb-models-$$.json)"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' -m 20 \
    -H 'Accept: application/json' "${SITE_URL}/api/v1/models" 2>/dev/null || echo 000)"
  if [[ "$code" != "200" ]]; then
    echo "Could not fetch catalog (HTTP $code)" >&2
    rm -f "$tmp" 2>/dev/null || true
    exit 1
  fi
  FREE_ONLY="$free_only" PAID_ONLY="$paid_only" ROUTERS_ONLY="$routers_only" python3 - "$tmp" <<'PY'
import json, os, sys
path = sys.argv[1]
free_only = os.environ.get("FREE_ONLY") == "1"
paid_only = os.environ.get("PAID_ONLY") == "1"
routers_only = os.environ.get("ROUTERS_ONLY") == "1"
j = json.load(open(path))
rows = j.get("yieldingbear", {}).get("data") or j.get("data") or []
rows = sorted(
    rows,
    key=lambda m: (
        0 if (m.get("is_virtual") or str(m.get("id") or "").startswith("yieldingbear/")) else 1,
        0 if m.get("is_free") else 1,
        0 if m.get("is_active", True) else 1,
        str(m.get("id") or ""),
    ),
)
n = 0
print("id\ttags\t$/1M in→out\tname")
for m in rows:
    mid = m.get("id") or "?"
    is_free = m.get("is_free") is True
    is_router = m.get("is_virtual") is True or str(mid).startswith("yieldingbear/")
    if free_only and not is_free:
        continue
    if paid_only and is_free:
        continue
    if routers_only and not is_router:
        continue
    tags = []
    tags.append("free" if is_free else "paid")
    if m.get("is_active") is False:
        tags.append("inactive")
    if is_router:
        tags.append("router")
    pr = m.get("pricing") or {}
    try:
        inp = float(pr.get("input_per_mtok_usd") or 0)
        out = float(pr.get("output_per_mtok_usd") or 0)
    except Exception:
        inp = out = 0.0
    if is_free:
        price = "0/0"
    elif is_router and inp == 0 and out == 0:
        price = "routed"
    else:
        price = f"{inp:g}/{out:g}"
    name = m.get("name") or m.get("display_name") or ""
    print(f"{mid}\t[{','.join(tags)}]\t{price}\t{name}")
    n += 1
print(f"# {n} models", file=sys.stderr)
PY
  rm -f "$tmp" 2>/dev/null || true
}

cmd_smoke() {
  load_key
  if [[ -z "$KEY" ]]; then
    echo "No API key. Run: bash scripts/install.sh" >&2
    exit 1
  fi
  model="${1:-}"
  if [[ -z "$model" && -f "$CONFIG_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    model="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("default_model") or "")' "$CONFIG_FILE" 2>/dev/null || true)"
  fi
  model="${model:-liquid/lfm-2.5-2.6b}"
  code="$(curl -sS -o /tmp/yb-smoke.json -w '%{http_code}' -m 60 \
    -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ready\"}],\"max_tokens\":8}" \
    2>/dev/null || echo 000)"
  echo "HTTP $code model=$model"
  if command -v python3 >/dev/null 2>&1 && [[ -f /tmp/yb-smoke.json ]]; then
    python3 <<'PY' 2>/dev/null || head -c 400 /tmp/yb-smoke.json
import json
j = json.load(open("/tmp/yb-smoke.json"))
if j.get("error"):
    print("error:", j["error"])
else:
    c = (j.get("choices") or [{}])[0]
    t = (c.get("message") or {}).get("content") or ""
    print("reply:", (t or "").strip()[:120])
PY
  fi
  rm -f /tmp/yb-smoke.json 2>/dev/null || true
}

cmd_set_model() {
  resolve_paths
  mid="${1:-}"
  if [[ -z "$mid" ]]; then
    echo "Usage: yb.sh set-model <model_id>" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || true
  if [[ -f "$CONFIG_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG_FILE" "$mid" <<'PY'
import json, sys
path, mid = sys.argv[1], sys.argv[2]
try:
    c = json.load(open(path))
except Exception:
    c = {"version": "2.2.0"}
c["default_model"] = mid
json.dump(c, open(path, "w"), indent=2)
print("updated", path)
PY
  else
    cat > "$CONFIG_FILE" <<EOF
{
  "version": "${VERSION}",
  "base_url": "${BASE_URL}",
  "default_model": "${mid}",
  "key_file": "${KEY_FILE}"
}
EOF
  fi
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
  if [[ -f "$ENV_FILE" ]]; then
    if grep -q 'YIELDINGBEAR_DEFAULT_MODEL=' "$ENV_FILE" 2>/dev/null; then
      # portable-ish rewrite
      tmp="$(mktemp)"
      sed "s|^export YIELDINGBEAR_DEFAULT_MODEL=.*|export YIELDINGBEAR_DEFAULT_MODEL=\"${mid}\"|" "$ENV_FILE" > "$tmp"
      mv "$tmp" "$ENV_FILE"
      chmod 600 "$ENV_FILE" 2>/dev/null || true
    else
      echo "export YIELDINGBEAR_DEFAULT_MODEL=\"${mid}\"" >> "$ENV_FILE"
    fi
  fi
  echo "default_model → ${mid}"
}

cmd_explain() {
  cat <<EOF
Yielding Bear routing (confirmed gateway behavior)

  Virtual model: yieldingbear/grizzly-1.0g-pro
  • Classifies prompt reasoning need → high / mid / low
  • Picks cost-aware defaults (Pro routes):
      high → frontier reasoner (e.g. Claude Sonnet-class)
      mid  → fast cheap (e.g. Gemini Flash-class)
      low  → free/active nano when available (soft-fail → mid)
  • Live I/O \$/1M from model_config drives billing + savings baseline
  • Optional: semantic response cache + prompt-cache flags (server)
  • Optional: Thompson-sampling bandit over tier picks when enabled
    (self-improves from outcomes — not a guarantee every account)

  Free path: pick any is_free catalog model or low tier via Grizzly.
  Paid path: wallet credits or Grizzly Pro (\$99/mo).

  CLI signup offer: \$10 off Pro first 3 months (\$89→\$99)
    open ${SITE_URL}/offer/cli10x3
  Referral (bound only): \$20 off first Pro month (~\$79 once)
    — never stacked with CLI offer.

  Commands:
    yb.sh models [--free|--paid|--routers]
    yb.sh set-model <id>
    yb.sh doctor
    yb.sh smoke [model]
EOF
  rcode="$(curl -sS -o /tmp/yb-explain-route.json -w '%{http_code}' -m 12 \
    "${SITE_URL}/api/health/grizzly-routing" 2>/dev/null || echo 000)"
  if [[ "$rcode" == "200" ]] && command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "Live routes:"
    python3 <<'PY' 2>/dev/null || true
import json
j=json.load(open("/tmp/yb-explain-route.json"))
tiers=j.get("tiers") or {}
for k in ("high","mid","low"):
    x=tiers.get(k) or {}
    if x.get("model"):
        print(f"  {k}: {x.get('model')}  (free={x.get('is_free')} ${x.get('input_per_mtok_usd')}/${x.get('output_per_mtok_usd')} per 1M)")
print("  ok:", j.get("ok"), "checked:", j.get("checked_at"))
PY
  fi
  rm -f /tmp/yb-explain-route.json 2>/dev/null || true
}

cmd_install() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "${SCRIPT_DIR}/install.sh" "$@"
}

usage() {
  cat <<EOF
yb.sh v${VERSION} — Yielding Bear skill helper

  yb.sh install              Interactive full setup
  yb.sh status               Paths + key + default model
  yb.sh doctor               Catalog + routing + chat health
  yb.sh models [--free|--paid|--routers]
  yb.sh set-model <id>       Switch default model in config
  yb.sh explain              Routing / cache / offers (honest)
  yb.sh smoke [model]        Tiny chat completion
EOF
}

main() {
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    install) cmd_install "$@" ;;
    status) cmd_status "$@" ;;
    doctor) cmd_doctor "$@" ;;
    models) cmd_models "$@" ;;
    set-model|set_model) cmd_set_model "$@" ;;
    explain) cmd_explain "$@" ;;
    smoke) cmd_smoke "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
