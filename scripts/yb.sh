#!/usr/bin/env bash
# Yielding Bear — doctor/status/models/smoke CLI (ClawHub skill helper)
# Usage: yb.sh <doctor|status|models|smoke|install> [--free]
set -euo pipefail

SITE_URL="${YIELDINGBEAR_SITE_URL:-https://yieldingbear.com}"
BASE_URL="${YIELDINGBEAR_BASE_URL:-${SITE_URL}/api/v1}"
VERSION="2.0.0"

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
paid_free_name = [
    m for m in rows
    if m.get("is_free") is not True
    and "(Free)" in str(m.get("name") or m.get("display_name") or "")
]
inactive_free = [m for m in free if m.get("is_active") is False]
print(f"  OK  catalog rows={len(rows)} free={len(free)} inactive_free={len(inactive_free)}")
if paid_free_name:
    ids = ", ".join(m.get("id", "?") for m in paid_free_name[:8])
    print("  WARN display '(Free)' on non-free:", ids)
if inactive_free:
    ids = ", ".join(m.get("id", "?") for m in inactive_free[:8])
    print("  WARN inactive free:", ids)
PY
    fi
  else
    echo "  FAIL GET /api/v1/models HTTP $code"
  fi

  load_key
  if [[ -z "$KEY" ]]; then
    echo "  SKIP chat (no API key) — set YIELDINGBEAR_API_KEY or run install"
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
  rm -f /tmp/yb-doc-models.json /tmp/yb-doc-chat.json 2>/dev/null || true
}

cmd_models() {
  free_only=0
  [[ "${1:-}" == "--free" ]] && free_only=1
  tmp="$(mktemp -t yb-models.XXXXXX 2>/dev/null || echo /tmp/yb-models-$$.json)"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' -m 20 \
    -H 'Accept: application/json' "${SITE_URL}/api/v1/models" 2>/dev/null || echo 000)"
  if [[ "$code" != "200" ]]; then
    echo "Could not fetch catalog (HTTP $code)" >&2
    rm -f "$tmp" 2>/dev/null || true
    exit 1
  fi
  FREE_ONLY="$free_only" python3 - "$tmp" <<'PY'
import json, os, sys
path = sys.argv[1]
free_only = os.environ.get("FREE_ONLY") == "1"
j = json.load(open(path))
rows = j.get("yieldingbear", {}).get("data") or j.get("data") or []
rows = sorted(
    rows,
    key=lambda m: (
        0 if m.get("is_free") else 1,
        0 if m.get("is_active", True) else 1,
        str(m.get("id") or ""),
    ),
)
n = 0
for m in rows:
    if free_only and not m.get("is_free"):
        continue
    mid = m.get("id") or "?"
    tags = []
    tags.append("free" if m.get("is_free") else "paid")
    if m.get("is_active") is False:
        tags.append("inactive")
    if m.get("is_virtual") or str(mid).startswith("yieldingbear/"):
        tags.append("router")
    name = m.get("name") or m.get("display_name") or ""
    print(f"{mid}\t[{','.join(tags)}]\t{name}")
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

cmd_install() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "${SCRIPT_DIR}/install.sh" "$@"
}

usage() {
  cat <<EOF
yb.sh v${VERSION} — Yielding Bear skill helper

  yb.sh install          Run interactive installer
  yb.sh status           Show runtime paths + key
  yb.sh doctor           Catalog + key + chat health
  yb.sh models [--free]  List live catalog
  yb.sh smoke [model]    Tiny chat completion
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
    smoke) cmd_smoke "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
