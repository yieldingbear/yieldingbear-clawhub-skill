/**
 * Yielding Bear OpenClaw plugin — before_model_resolve companion.
 * Fail closed to yieldingbear/grizzly-1.0g-pro on errors.
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  AUTO_ROUTER,
  mergeHealthTiers,
  selectModelOverride,
} from "./lib/rails.js";

const DEFAULT_HEALTH =
  "https://yieldingbear.com/api/health/grizzly-routing";

function home() {
  return process.env.HOME || process.env.USERPROFILE || os.homedir();
}

function defaultOpsConfigPath() {
  const openclaw = path.join(home(), ".openclaw", "config", "yieldingbear", "grizzly-ops.json");
  const hermes = path.join(home(), ".hermes", "config", "yieldingbear", "grizzly-ops.json");
  if (fs.existsSync(openclaw)) return openclaw;
  if (fs.existsSync(hermes)) return hermes;
  return openclaw;
}

function decisionsPath() {
  const base = path.join(home(), ".openclaw", "config", "yieldingbear");
  try {
    fs.mkdirSync(base, { recursive: true });
  } catch {
    /* ignore */
  }
  return path.join(base, "decisions.jsonl");
}

function loadOpsConfig(p) {
  try {
    if (p && fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    /* ignore */
  }
  return {};
}

function sessionSpendUsd(receiptsFile) {
  try {
    if (!fs.existsSync(receiptsFile)) return 0;
    const lines = fs.readFileSync(receiptsFile, "utf8").split("\n").filter(Boolean);
    const cutoff = Date.now() - 4 * 3600 * 1000;
    let sum = 0;
    for (const line of lines) {
      try {
        const r = JSON.parse(line);
        const ts = r.ts ? Date.parse(r.ts) : Date.now();
        if (ts < cutoff) continue;
        if (r.cost_usd != null) sum += Number(r.cost_usd) || 0;
      } catch {
        /* ignore */
      }
    }
    return sum;
  } catch {
    return 0;
  }
}

function appendDecision(row) {
  try {
    const p = decisionsPath();
    fs.appendFileSync(p, JSON.stringify(row) + "\n", { mode: 0o600 });
  } catch {
    /* ignore */
  }
}

/** Simple in-memory health cache */
let healthCache = { at: 0, tiers: {} };

async function fetchHealthTiers(url, cacheMs) {
  const now = Date.now();
  if (healthCache.tiers && now - healthCache.at < cacheMs) return healthCache.tiers;
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 8000);
    const res = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: ctrl.signal,
    });
    clearTimeout(t);
    if (!res.ok) throw new Error(`health ${res.status}`);
    const j = await res.json();
    const tiers = mergeHealthTiers(j);
    healthCache = { at: now, tiers };
    return tiers;
  } catch {
    return healthCache.tiers || {};
  }
}

function dailyCapForceFree(ops, spendToday) {
  const cap = ops.daily_usd_cap;
  if (cap == null || cap === "") return false;
  const n = Number(cap);
  if (!Number.isFinite(n)) return false;
  return spendToday >= n;
}

export default {
  id: "yieldingbear",
  name: "Yielding Bear",
  description:
    "before_model_resolve → Yielding Bear Auto / high|mid|free (fail closed to Auto router)",
  register(api) {
    const cfg = api.pluginConfig || {};
    if (cfg.enabled === false) return;

    const defaultModel = cfg.defaultModel || AUTO_ROUTER;
    const providerOverride = cfg.providerOverride || "yieldingbear";
    const healthUrl = cfg.healthUrl || DEFAULT_HEALTH;
    const cacheMs = Number(cfg.healthCacheMs ?? 60_000);

    api.on("before_model_resolve", async (event) => {
      try {
        const opsPath = cfg.opsConfigPath || defaultOpsConfigPath();
        const ops = loadOpsConfig(opsPath);
        const receipts = path.join(
          path.dirname(opsPath),
          "receipts.jsonl",
        );
        const spend = sessionSpendUsd(receipts);
        // crude today spend: reuse session window file scan for cap
        const forceFree =
          dailyCapForceFree(ops, spend) ||
          (ops.burn_down &&
            spend >= Number(ops.burn_down.hard_stop_paid_usd || 15));

        const tiers = await fetchHealthTiers(healthUrl, cacheMs);
        const decision = selectModelOverride({
          prompt: event?.prompt || "",
          opsConfig: ops,
          healthTiers: tiers,
          defaultModel,
          forceFree,
        });

        appendDecision({
          ts: new Date().toISOString(),
          skill: decision.skill,
          rail: decision.rail,
          model: decision.modelOverride,
          reason: decision.reason,
          session_spend: spend,
        });

        const out = {
          modelOverride: decision.modelOverride || defaultModel,
        };
        // Only set provider when we control routing toward YB-shaped ids
        if (providerOverride) {
          out.providerOverride = providerOverride;
        }
        return out;
      } catch (err) {
        appendDecision({
          ts: new Date().toISOString(),
          skill: null,
          rail: "auto",
          model: defaultModel,
          reason: `hook_error:${String(err && err.message ? err.message : err)}`,
          session_spend: null,
        });
        // Fail closed to Auto router, not Opus
        return {
          modelOverride: defaultModel,
          providerOverride,
        };
      }
    });
  },
};
