#!/usr/bin/env bash
# Yielding Bear — doctor/status/models/smoke/set-model/set-routing/explain CLI
# Usage: yb.sh <cmd> …
set -euo pipefail

SITE_URL="${YIELDINGBEAR_SITE_URL:-https://yieldingbear.com}"
BASE_URL="${YIELDINGBEAR_BASE_URL:-${SITE_URL}/api/v1}"
VERSION="2.5.0"
GRIZZLY="yieldingbear/grizzly-1.0g-pro"

# Build Authorization header without embedding secrets in source comments.
auth_header() {
  # $1 = raw API key
  printf 'Authorization: Bearer %s' "$1"
}

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
  elif [[ -n "${YB_API_KEY:-}" ]]; then
    KEY="$YB_API_KEY"
  elif [[ -s "$KEY_FILE" ]]; then
    KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
  else
    KEY=""
  fi
}

cfg_get() {
  # $1 = json key
  if [[ -f "$CONFIG_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(c.get(sys.argv[2]) or "")' \
      "$CONFIG_FILE" "$1" 2>/dev/null || true
  fi
}

fetch_recs() {
  REC_HIGH="" REC_MID="" REC_LOW="" REC_ROUTER="$GRIZZLY"
  PRICE_HIGH="" PRICE_MID="" PRICE_LOW=""
  CACHE_FLAG=""
  local j
  j="$(curl -sS -m 12 -H 'Accept: application/json' \
    "${SITE_URL}/api/public/routing-recommendations" 2>/dev/null || true)"
  if command -v python3 >/dev/null 2>&1 && [[ -n "$j" ]]; then
    eval "$(
      printf '%s' "$j" | python3 -c '
import json,sys,shlex
try: j=json.load(sys.stdin)
except Exception: sys.exit(0)
def q(s): return shlex.quote(str(s or ""))
print("REC_HIGH="+q(j.get("high")))
print("REC_MID="+q(j.get("mid")))
print("REC_LOW="+q(j.get("low")))
print("REC_ROUTER="+q(j.get("router_model") or "yieldingbear/grizzly-1.0g-pro"))
' 2>/dev/null || true
    )"
  fi
  [[ -n "$REC_HIGH" ]] || REC_HIGH="anthropic/claude-sonnet-4.6"
  [[ -n "$REC_MID" ]] || REC_MID="google/gemini-2.5-flash"
  [[ -n "$REC_LOW" ]] || REC_LOW="nvidia/nemotron-3-nano-30b"
  [[ -n "$REC_ROUTER" ]] || REC_ROUTER="$GRIZZLY"

  # Live $/1M from routing health only — never invent
  local h
  h="$(curl -sS -m 12 -H 'Accept: application/json' \
    "${SITE_URL}/api/health/grizzly-routing" 2>/dev/null || true)"
  if command -v python3 >/dev/null 2>&1 && [[ -n "$h" ]]; then
    eval "$(
      printf '%s' "$h" | python3 -c '
import json,sys,shlex
try: j=json.load(sys.stdin)
except Exception: sys.exit(0)
def q(s): return shlex.quote(str(s or ""))
tiers=j.get("tiers") or {}
def price(t):
    row=tiers.get(t) or {}
    if not row: return ""
    try:
        i=float(row.get("input_per_mtok_usd") if row.get("input_per_mtok_usd") is not None else 0)
        o=float(row.get("output_per_mtok_usd") if row.get("output_per_mtok_usd") is not None else 0)
    except Exception:
        return ""
    mid=str(row.get("model") or "")
    free=row.get("is_free") is True
    if free:
        return f"{mid}  $0/$0 per 1M in/out (free)"
    return f"{mid}  ${i:g}/${o:g} per 1M in/out"
print("PRICE_HIGH="+q(price("high")))
print("PRICE_MID="+q(price("mid")))
print("PRICE_LOW="+q(price("low")))
flags=[]
for k in ("semantic_cache","prompt_cache","cache_enabled","bandit","bandit_enabled"):
    if k in j:
        flags.append(f"{k}={j.get(k)}")
for section in (j.get("flags") or {}, j.get("features") or {}):
    if isinstance(section, dict):
        for k,v in section.items():
            if any(x in str(k).lower() for x in ("cache","bandit")):
                flags.append(f"{k}={v}")
print("CACHE_FLAG="+q("; ".join(flags)))
' 2>/dev/null || true
    )"
  fi
  return 0
}

write_config_fields() {
  # args via env: NEW_MODE NEW_MODEL
  resolve_paths
  mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || true
  fetch_recs
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG_FILE" "${NEW_MODE}" "${NEW_MODEL}" "$VERSION" "$BASE_URL" \
      "$REC_HIGH" "$REC_MID" "$REC_LOW" "$REC_ROUTER" "$KEY_FILE" <<'PY'
import json, sys
path, mode, model, ver, base, hi, mid, lo, router, keyf = sys.argv[1:11]
try:
    c = json.load(open(path))
except Exception:
    c = {}
c["version"] = ver
c["base_url"] = base
c["routing_mode"] = mode
c["default_model"] = model
c["recommended_tiers"] = {"high": hi, "mid": mid, "low": lo}
c.setdefault("fallback_models", [router, lo, "liquid/lfm-2.5-2.6b"])
c["key_file"] = keyf
json.dump(c, open(path, "w"), indent=2)
print("updated", path)
PY
  else
    cat > "$CONFIG_FILE" <<EOF
{
  "version": "${VERSION}",
  "base_url": "${BASE_URL}",
  "routing_mode": "${NEW_MODE}",
  "default_model": "${NEW_MODEL}",
  "key_file": "${KEY_FILE}"
}
EOF
  fi
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true

  # env.sh
  if [[ -f "$ENV_FILE" ]]; then
    tmp="$(mktemp)"
    if grep -q 'YIELDINGBEAR_DEFAULT_MODEL=' "$ENV_FILE" 2>/dev/null; then
      sed "s|^export YIELDINGBEAR_DEFAULT_MODEL=.*|export YIELDINGBEAR_DEFAULT_MODEL=\"${NEW_MODEL}\"|" "$ENV_FILE" > "$tmp"
      mv "$tmp" "$ENV_FILE"
    else
      echo "export YIELDINGBEAR_DEFAULT_MODEL=\"${NEW_MODEL}\"" >> "$ENV_FILE"
    fi
    if grep -q 'YIELDINGBEAR_ROUTING_MODE=' "$ENV_FILE" 2>/dev/null; then
      tmp="$(mktemp)"
      sed "s|^export YIELDINGBEAR_ROUTING_MODE=.*|export YIELDINGBEAR_ROUTING_MODE=\"${NEW_MODE}\"|" "$ENV_FILE" > "$tmp"
      mv "$tmp" "$ENV_FILE"
    else
      echo "export YIELDINGBEAR_ROUTING_MODE=\"${NEW_MODE}\"" >> "$ENV_FILE"
    fi
    chmod 600 "$ENV_FILE" 2>/dev/null || true
  fi
}

sync_server_prefs() {
  load_key
  [[ -z "$KEY" ]] && return 0
  local model="${1:-$GRIZZLY}"
  local tier="${2:-auto}"
  local body
  body="$(printf '{"active_default_model":"%s","routing_tier":"%s","tier_routes":null}' "$model" "$tier")"
  curl -sS -m 20 -o /tmp/yb-pref-sync.json -w '' \
    -X PUT "${SITE_URL}/api/user/default-model" \
    -H "$(auth_header "$KEY")" \
    -H "Content-Type: application/json" \
    -d "$body" >/dev/null 2>&1 || true
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
print("  mode:    ", c.get("routing_mode") or "(legacy)")
print("  model:   ", c.get("default_model") or "(none)")
print("  cfg ver: ", c.get("version") or "(none)")
fb = c.get("fallback_models") or []
print("  fallback:", ", ".join(fb) if fb else "(none)")
rt = c.get("recommended_tiers") or {}
if rt:
    print("  rec high:", rt.get("high") or "")
    print("  rec mid: ", rt.get("mid") or "")
    print("  rec free:", rt.get("low") or "")
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
  else
    echo "  FAIL GET /api/v1/models ($code)"
  fi

  rcode="$(curl -sS -o /tmp/yb-doc-route.json -w '%{http_code}' -m 15 \
    -H 'Accept: application/json' \
    "${SITE_URL}/api/public/routing-recommendations" 2>/dev/null || echo 000)"
  if [[ "$rcode" == "200" ]]; then
    echo "  OK  GET /api/public/routing-recommendations ($rcode)"
    if command -v python3 >/dev/null 2>&1; then
      python3 <<'PY' 2>/dev/null || true
import json
j=json.load(open("/tmp/yb-doc-route.json"))
print(f"      mode auto → {j.get('router_model')}")
print(f"      high={j.get('high')}  mid={j.get('mid')}  free={j.get('low')}")
PY
    fi
  else
    echo "  FAIL GET routing-recommendations ($rcode)"
  fi

  hcode="$(curl -sS -o /tmp/yb-doc-health.json -w '%{http_code}' -m 15 \
    "${SITE_URL}/api/health/grizzly-routing" 2>/dev/null || echo 000)"
  if [[ "$hcode" == "200" ]]; then
    echo "  OK  GET /api/health/grizzly-routing ($hcode)"
  else
    echo "  FAIL GET /api/health/grizzly-routing ($hcode)"
  fi

  load_key
  if [[ -n "$KEY" ]]; then
    scode="$(curl -sS -o /tmp/yb-doc-pref.json -w '%{http_code}' -m 15 \
      -H "$(auth_header "$KEY")" \
      "${SITE_URL}/api/user/default-model" 2>/dev/null || echo 000)"
    if [[ "$scode" == "200" ]]; then
      echo "  OK  GET /api/user/default-model ($scode)"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$CONFIG_FILE" <<'PY' 2>/dev/null || true
import json, sys, os
srv=json.load(open("/tmp/yb-doc-pref.json"))
local_mode=local_model=""
path=sys.argv[1] if len(sys.argv)>1 else ""
if path and os.path.isfile(path):
    try:
        c=json.load(open(path))
        local_mode=c.get("routing_mode") or ""
        local_model=c.get("default_model") or ""
    except Exception:
        pass
s_model=srv.get("active_default_model") or ""
print(f"      server default={s_model}  routing_tier={srv.get('routing_tier')}")
if local_model and s_model and local_model != s_model:
    print(f"      WARN local model ({local_model}) ≠ server ({s_model}) — run set-routing to sync")
if local_mode:
    print(f"      local routing_mode={local_mode}")
PY
      fi
    else
      echo "  FAIL GET /api/user/default-model ($scode)"
    fi
  else
    echo "  SKIP server prefs (no API key)"
  fi
  # Fake "(Free)" label on non-free rows + capture a live free id
  if [[ -f /tmp/yb-doc-models.json ]] && command -v python3 >/dev/null 2>&1; then
    python3 <<'PY' 2>/dev/null || true
import json, re
j=json.load(open("/tmp/yb-doc-models.json"))
rows=(j.get("yieldingbear") or {}).get("data") or j.get("data") or []
bad=[]
for m in rows:
    name=str(m.get("display_name") or m.get("name") or "")
    is_free=m.get("is_free") is True
    if re.search(r"\(Free\)", name, re.I) and not is_free:
        bad.append(str(m.get("id") or name))
if bad:
    print("  WARN display (Free) on non-free rows:")
    for b in bad[:12]:
        print("      ", b)
else:
    print("  OK  no fake (Free) labels on non-free rows")
free_ids=[str(m.get("id")) for m in rows if m.get("is_free") is True and m.get("id")]
open("/tmp/yb-doc-free-id.txt","w").write(free_ids[0] if free_ids else "")
print(f"  OK  live free catalog count={len(free_ids)}")
PY
  fi

  # Free-model smoke (live free id only)
  load_key
  FREE_ID="$(cat /tmp/yb-doc-free-id.txt 2>/dev/null || true)"
  if [[ -n "$KEY" && -n "$FREE_ID" ]]; then
    echo "  … smoke free model ${FREE_ID}"
    scode="$(curl -sS -o /tmp/yb-doc-smoke.json -w '%{http_code}' -m 45 \
      -X POST "${BASE_URL}/chat/completions" \
      -H "$(auth_header "$KEY")" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${FREE_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ready\"}],\"max_tokens\":8}" \
      2>/dev/null || echo 000)"
    if [[ "$scode" == "200" ]]; then
      echo "  OK  free smoke HTTP $scode"
    else
      echo "  FAIL free smoke HTTP $scode (key/plan/rate-limit — check body)"
      head -c 240 /tmp/yb-doc-smoke.json 2>/dev/null; echo
    fi
    rm -f /tmp/yb-doc-smoke.json 2>/dev/null || true
  elif [[ -z "$KEY" ]]; then
    echo "  skip free smoke (no key)"
  else
    echo "  skip free smoke (no free id in catalog)"
  fi
  rm -f /tmp/yb-doc-models.json /tmp/yb-doc-route.json /tmp/yb-doc-health.json /tmp/yb-doc-pref.json /tmp/yb-doc-free-id.txt 2>/dev/null || true

}


cmd_models() {
  local filter=""
  case "${1:-}" in
    --free) filter=free ;;
    --paid) filter=paid ;;
    --routers) filter=routers ;;
  esac
  fetch_recs
  echo "# recommendations  high=${REC_HIGH}  mid=${REC_MID}  free=${REC_LOW}  router=${REC_ROUTER}"
  tmp="$(mktemp)"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' -m 25 \
    -H 'Accept: application/json' "${SITE_URL}/api/v1/models" 2>/dev/null || echo 000)"
  if [[ "$code" != "200" ]]; then
    echo "Failed to fetch models (HTTP $code)" >&2
    rm -f "$tmp"
    exit 1
  fi
  python3 - "$tmp" "$filter" "$REC_HIGH" "$REC_MID" "$REC_LOW" "$REC_ROUTER" <<'PY'
import json, sys
path, filt, hi, mid, lo, router = sys.argv[1:7]
stars = {hi: "★high", mid: "★mid", lo: "★free", router: "★auto"}
data = json.load(open(path))
rows = data.get("yieldingbear", {}).get("data") or data.get("data") or []
n = 0
for m in rows:
    mid_ = str(m.get("id") or "")
    if not mid_:
        continue
    is_free = m.get("is_free") is True
    is_router = m.get("is_virtual") is True or mid_.startswith("yieldingbear/")
    if filt == "free" and not is_free:
        continue
    if filt == "paid" and is_free:
        continue
    if filt == "routers" and not is_router:
        continue
    tags = []
    tags.append("free" if is_free else "paid")
    if m.get("is_active") is False:
        tags.append("inactive")
    if is_router:
        tags.append("router")
    star = stars.get(mid_, "")
    if star:
        tags.append(star)
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
    print(f"{mid_}\t[{','.join(tags)}]\t{price}\t{name}")
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
  if [[ -z "$model" ]]; then
    fetch_recs
    model="${REC_LOW:-}"
  fi
  if [[ -z "$model" ]]; then
    model="$(curl -sS -m 15 -H 'Accept: application/json' "${SITE_URL}/api/v1/models" 2>/dev/null | python3 -c 'import json,sys
j=json.load(sys.stdin)
rows=(j.get("yieldingbear") or {}).get("data") or j.get("data") or []
for m in rows:
  if m.get("is_free") is True and m.get("id"):
    print(m["id"]); break
' 2>/dev/null || true)"
  fi
  model="${model:-nvidia/nemotron-3-nano-30b}"
  code="$(curl -sS -o /tmp/yb-smoke.json -w '%{http_code}' -m 60 \
    -X POST "${BASE_URL}/chat/completions" \
    -H "$(auth_header "$KEY")" \
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
  mid="${1:-}"
  if [[ -z "$mid" ]]; then
    echo "Usage: yb.sh set-model <model_id>" >&2
    exit 1
  fi
  NEW_MODE="manual"
  NEW_MODEL="$mid"
  # If user pins the router, treat as auto
  if [[ "$mid" == "$GRIZZLY" || "$mid" == yieldingbear/grizzly-1.0g* ]]; then
    NEW_MODE="auto"
    NEW_MODEL="$GRIZZLY"
  fi
  write_config_fields
  sync_server_prefs "$NEW_MODEL" "$NEW_MODE"
  echo "routing_mode → ${NEW_MODE}"
  echo "default_model → ${NEW_MODEL}"
}

cmd_set_routing() {
  mode="${1:-}"
  pin="${2:-}"
  mode="$(printf '%s' "$mode" | tr 'A-Z' 'a-z')"
  case "$mode" in
    auto|a)
      NEW_MODE="auto"
      NEW_MODEL="$GRIZZLY"
      ;;
    manual|man|m)
      NEW_MODE="manual"
      fetch_recs
      if [[ -n "$pin" ]]; then
        NEW_MODEL="$pin"
      else
        # keep existing or recommend free
        resolve_paths
        cur="$(cfg_get default_model)"
        NEW_MODEL="${cur:-$REC_LOW}"
        [[ -z "$NEW_MODEL" ]] && NEW_MODEL="$REC_LOW"
      fi
      ;;
    *)
      echo "Usage: yb.sh set-routing auto|manual [model_id]" >&2
      echo "  auto   → Grizzly classifies high/mid/free per prompt" >&2
      echo "  manual → pin one catalog model (optional id; YB recs via yb.sh models)" >&2
      exit 1
      ;;
  esac
  write_config_fields
  sync_server_prefs "$NEW_MODEL" "$NEW_MODE"
  echo "routing_mode → ${NEW_MODE}"
  echo "default_model → ${NEW_MODEL}"
  echo "Dashboard mirror: ${SITE_URL}/dashboard?tab=developer"
}

cmd_explain() {
  fetch_recs
  printf '%s\n' \
    "Yielding Bear routing (live)" \
    "" \
    "  Modes:" \
    "    auto   -> ${REC_ROUTER}" \
    "             classifies each prompt -> high / mid / free" \
    "    manual -> pin any catalog model (yb.sh set-model <id>)" \
    "" \
    "  Live rails (ids from public recs; $/1M from /api/health/grizzly-routing when present):"
  if [[ -n "$PRICE_HIGH" || -n "$PRICE_MID" || -n "$PRICE_LOW" ]]; then
    printf '%s\n' \
      "    high  ${PRICE_HIGH:-$REC_HIGH}" \
      "    mid   ${PRICE_MID:-$REC_MID}" \
      "    free  ${PRICE_LOW:-$REC_LOW}"
  else
    printf '%s\n' \
      "    high  ${REC_HIGH}" \
      "    mid   ${REC_MID}" \
      "    free  ${REC_LOW}" \
      "    (no live $/1M — health endpoint unavailable; not inventing prices)"
  fi
  if [[ -n "$CACHE_FLAG" ]]; then
    printf '%s\n' "" "  Server flags (as reported): ${CACHE_FLAG}"
  fi
  printf '%s\n' \
    "" \
    "  Explicit request body \"model\" always wins over account default." \
    "  Free plan is 60 RPM — 429 on free is expected under load, not a signal to jump rails." \
    "" \
    "  CLI Pro offer: \$10 off first 3 months (\$89 then \$99)  ${SITE_URL}/offer/cli10x3" \
    "  Referral \$20 first month does not stack with CLI offer." \
    "" \
    "  yb.sh set-routing auto|manual [id]" \
    "  yb.sh models --free" \
    "  yb.sh doctor | smoke"
}

cmd_why() {
  cmd_explain "$@"
}

cmd_install() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "${SCRIPT_DIR}/install.sh" "$@"
}


# --- ops: receipts / spend / vk-bind ---
ops_config_path() {
  resolve_paths
  local dir ybdir
  dir="$(dirname "$CONFIG_FILE")"
  if [[ "$(basename "$dir")" == "yieldingbear" ]]; then
    ybdir="$dir"
  else
    ybdir="${dir}/yieldingbear"
  fi
  mkdir -p "$ybdir" 2>/dev/null || true
  echo "${ybdir}/grizzly-ops.json"
}

receipts_path() {
  resolve_paths
  local dir cfg rp ybdir
  dir="$(dirname "$CONFIG_FILE")"
  # prefer .../config/yieldingbear/ when CONFIG_FILE is .../config/yieldingbear.json
  if [[ "$(basename "$dir")" == "yieldingbear" ]]; then
    ybdir="$dir"
  elif [[ "$(basename "$CONFIG_FILE")" == "yieldingbear.json" ]]; then
    ybdir="${dir}/yieldingbear"
  else
    ybdir="${dir}/yieldingbear"
  fi
  cfg="$(ops_config_path)"
  rp=""
  if [[ -f "$cfg" ]] && command -v python3 >/dev/null 2>&1; then
    rp="$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(c.get("receipts_path") or "")' "$cfg" 2>/dev/null || true)"
  fi
  if [[ -n "$rp" ]]; then
    echo "$rp"
  else
    echo "${ybdir}/receipts.jsonl"
  fi
}

cmd_receipts() {
  resolve_paths
  local path action n line
  path="$(receipts_path)"
  action="${1:-}"
  case "$action" in
    --tail|tail)
      n="${2:-20}"
      if [[ ! -f "$path" ]]; then
        echo "no receipts yet: $path"
        return 0
      fi
      tail -n "$n" "$path"
      ;;
    --append|append)
      shift || true
      line="${1:-}"
      if [[ -z "$line" ]]; then
        echo "Usage: yb.sh receipts --append '<json object>'" >&2
        exit 1
      fi
      mkdir -p "$(dirname "$path")" 2>/dev/null || true
      # validate JSON object; drop unknown requirement — agent may omit fields
      if command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "$line" | python3 -c '
import json,sys,datetime
raw=sys.stdin.read().strip()
obj=json.loads(raw)
if not isinstance(obj, dict):
    raise SystemExit("receipt must be a JSON object")
# strip nulls; never invent fields
obj={k:v for k,v in obj.items() if v is not None}
obj.setdefault("ts", datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
print(json.dumps(obj, separators=(",", ":")))
' >> "$path"
      else
        printf '%s\n' "$line" >> "$path"
      fi
      chmod 600 "$path" 2>/dev/null || true
      echo "appended → $path"
      ;;
    --path|path)
      echo "$path"
      ;;
    *)
      echo "Usage: yb.sh receipts --tail [N] | --append '<json>' | --path" >&2
      exit 1
      ;;
  esac
}

cmd_spend() {
  resolve_paths
  local path mode
  path="$(receipts_path)"
  mode="session"
  case "${1:-}" in
    --session|session) mode=session ;;
    --today|today) mode=today ;;
    --forecast|forecast) mode=forecast ;;
    -h|--help|help)
      echo "Usage: yb.sh spend [--session|--today|--forecast]"
      return 0
      ;;
    "") mode=session ;;
    *) echo "Unknown spend flag: $1" >&2; exit 1 ;;
  esac

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$path" "$mode" "$(ops_config_path)" <<'PY'
import json, sys, os, datetime
path, mode, cfg_path = sys.argv[1:4]
rows=[]
if os.path.isfile(path):
    with open(path) as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try:
                rows.append(json.loads(line))
            except Exception:
                pass

now=datetime.datetime.now(datetime.timezone.utc)
def parse_ts(s):
    if not s: return None
    s=str(s).replace("Z","+00:00")
    try:
        return datetime.datetime.fromisoformat(s)
    except Exception:
        return None

if mode=="today":
    start=now.replace(hour=0,minute=0,second=0,microsecond=0)
    rows=[r for r in rows if (parse_ts(r.get("ts")) or now) >= start]
elif mode=="session":
    # last 4 hours as session window if no session_id grouping
    start=now - datetime.timedelta(hours=4)
    # if any row has session_id matching latest, filter to that
    sid=None
    for r in reversed(rows):
        if r.get("session_id"):
            sid=r["session_id"]; break
    if sid:
        rows=[r for r in rows if r.get("session_id")==sid]
    else:
        rows=[r for r in rows if (parse_ts(r.get("ts")) or now) >= start]

cost=0.0
tin=tout=0
n=0
have_cost=False
for r in rows:
    n+=1
    if "cost_usd" in r and r["cost_usd"] is not None:
        try:
            cost += float(r["cost_usd"]); have_cost=True
        except Exception:
            pass
    if "tokens_in" in r and r["tokens_in"] is not None:
        try: tin += int(r["tokens_in"])
        except Exception: pass
    if "tokens_out" in r and r["tokens_out"] is not None:
        try: tout += int(r["tokens_out"])
        except Exception: pass

print(f"spend ({mode})  receipts={n}  path={path}")
if have_cost:
    print(f"  cost_usd: {cost:.6f}")
else:
    print("  cost_usd: (not present on receipts — not inventing)")
print(f"  tokens_in: {tin}  tokens_out: {tout}")

# burn-down thresholds from ops config
bd={"warn_usd":1.0,"demote_high_to_mid_usd":3.0,"demote_mid_to_free_usd":8.0,"hard_stop_paid_usd":15.0}
daily_cap=None
if os.path.isfile(cfg_path):
    try:
        c=json.load(open(cfg_path))
        bd={**bd, **(c.get("burn_down") or {})}
        daily_cap=c.get("daily_usd_cap")
    except Exception:
        pass
if have_cost:
    if cost >= float(bd.get("hard_stop_paid_usd") or 15):
        print("  action: HARD STOP paid (override required)")
    elif cost >= float(bd.get("demote_mid_to_free_usd") or 8):
        print("  action: demote mid → free")
    elif cost >= float(bd.get("demote_high_to_mid_usd") or 3):
        print("  action: demote high → mid")
    elif cost >= float(bd.get("warn_usd") or 1):
        print("  action: WARN spend")
    else:
        print("  action: ok")

if mode=="forecast":
    # simple burn rate from receipts with timestamps + cost
    timed=[]
    for r in rows:
        ts=parse_ts(r.get("ts"))
        if ts is None or "cost_usd" not in r: continue
        try: timed.append((ts, float(r["cost_usd"])))
        except Exception: pass
    if len(timed) < 2 or not have_cost:
        print("  forecast: estimate unavailable (need ≥2 timed cost receipts)")
    else:
        timed.sort()
        elapsed_h=max((timed[-1][0]-timed[0][0]).total_seconds()/3600.0, 1/60)
        rate=cost/elapsed_h
        print(f"  forecast: ~${rate:.4f}/hour (estimate from receipts, not a guarantee)")
        print(f"  forecast 24h: ~${rate*24:.2f} (estimate)")

# optional usage API — only if key + endpoint works; never invent shape
# try GET /api/v1/usage with bearer; print raw note on failure
print("  usage_api: local receipts only (authenticated /api/v1/usage shape not assumed)")
PY
  else
    echo "python3 required for spend" >&2
    exit 1
  fi
}

cmd_vk_bind() {
  resolve_paths
  local skill rail cfg
  skill="${1:-}"
  rail="${2:-}"
  rail="$(printf '%s' "$rail" | tr 'A-Z' 'a-z')"
  if [[ -z "$skill" || -z "$rail" ]]; then
    echo "Usage: yb.sh vk-bind <skill> <high|mid|free>" >&2
    echo "Records binding in grizzly-ops.json. Live virtual-key mint: blocked on API." >&2
    exit 1
  fi
  case "$rail" in high|mid|free|low) ;; *)
    echo "rail must be high|mid|free" >&2; exit 1 ;;
  esac
  [[ "$rail" == "low" ]] && rail=free
  cfg="$(ops_config_path)"
  mkdir -p "$(dirname "$cfg")" 2>/dev/null || true
  python3 - "$cfg" "$skill" "$rail" <<'PY'
import json,sys,os
path, skill, rail = sys.argv[1:4]
try:
    c=json.load(open(path)) if os.path.isfile(path) else {}
except Exception:
    c={}
c.setdefault("vk_bindings", {})
c["vk_bindings"][skill]=rail
c.setdefault("version", "1.0.0")
json.dump(c, open(path,"w"), indent=2)
print(f"vk-bind {skill} → {rail}  (config only; mint API not available)")
print(path)
PY
  chmod 600 "$cfg" 2>/dev/null || true
}


usage() {
  cat <<EOF
yb.sh v${VERSION} — Yielding Bear skill helper

  yb.sh install                       Interactive full setup
  yb.sh status                        Paths + key + routing mode
  yb.sh doctor                        Catalog + routing health + free smoke
  yb.sh models [--free|--paid|--routers]
  yb.sh set-routing auto|manual [id]  Auto-select or manual pin (default auto)
  yb.sh set-model <id>                Pin model (manual; router → auto)
  yb.sh why | explain                 Live rails + $/1M when health reports them
  yb.sh smoke [model]                 Tiny chat completion (prefers live free)
  yb.sh spend [--session|--today|--forecast]
  yb.sh receipts --tail [N] | --append '<json>' | --path
  yb.sh vk-bind <skill> <high|mid|free>   config only until VK API exists
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
    set-routing|set_routing|routing) cmd_set_routing "$@" ;;
    set-model|set_model) cmd_set_model "$@" ;;
    explain|why) cmd_explain "$@" ;;
    smoke) cmd_smoke "$@" ;;
    spend) cmd_spend "$@" ;;
    receipts) cmd_receipts "$@" ;;
    vk-bind|vk_bind) cmd_vk_bind "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
