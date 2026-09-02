/**
 * Pure rail selection + envelope stripping (no network).
 * Fail closed to Auto router id — never raw Anthropic/OpenAI as default override.
 */

export const AUTO_ROUTER = "yieldingbear/grizzly-1.0g-pro";

const DEFAULT_SKILL_RAILS = {
  github: "high",
  "code-review": "high",
  security: "high",
  architecture: "high",
  summarize: "free",
  notify: "free",
  gog: "free",
  triage: "free",
  format: "free",
  search: "mid",
  browser: "mid",
};

/**
 * Strip Slack/Telegram/CLI envelopes to a bare skill-ish token if present.
 * Does not copy third-party recruiting skill lists.
 */
export function stripEnvelope(prompt) {
  if (!prompt || typeof prompt !== "string") return "";
  let s = prompt;
  // common chat envelopes
  s = s.replace(/^\[.*?\]\s*/g, "");
  s = s.replace(/^<@[A-Z0-9]+>\s*/gi, "");
  s = s.replace(/^@\w+\s+/g, "");
  // "Skill: foo" / "/skill foo" / "using skill `foo`"
  const m =
    s.match(/(?:skill|using skill)\s*[:=]?\s*[`\"']?([a-z0-9][\w.-]{1,64})/i) ||
    s.match(/^\/([a-z][\w-]{1,64})\b/i);
  return { cleaned: s.trim(), skillHint: m ? m[1].toLowerCase() : null };
}

export function normalizeRail(rail) {
  if (!rail) return null;
  const r = String(rail).toLowerCase();
  if (r === "low") return "free";
  if (r === "high" || r === "mid" || r === "free") return r;
  return null;
}

/**
 * @param {object} opts
 * @param {string} opts.prompt
 * @param {object} [opts.opsConfig]
 * @param {object} [opts.healthTiers] map high|mid|low -> {model}
 * @param {string} [opts.defaultModel]
 * @param {boolean} [opts.forceFree] daily cap / burn-down
 */
export function selectModelOverride(opts = {}) {
  const defaultModel = opts.defaultModel || AUTO_ROUTER;
  const { cleaned, skillHint } = stripEnvelope(opts.prompt || "");
  const ops = opts.opsConfig || {};
  const skillRails = { ...DEFAULT_SKILL_RAILS, ...(ops.skill_rails || {}) };
  const vk = ops.vk_bindings || {};

  let rail = null;
  let reason = "auto-router";

  if (opts.forceFree) {
    rail = "free";
    reason = "daily_or_burn_force_free";
  } else if (skillHint && vk[skillHint]) {
    rail = normalizeRail(vk[skillHint]);
    reason = `vk_bind:${skillHint}`;
  } else if (skillHint && skillRails[skillHint]) {
    rail = normalizeRail(skillRails[skillHint]);
    reason = `skill_rail:${skillHint}`;
  } else if (ops.routing_mode === "manual" && ops.default_model) {
    // manual pin — still YB catalog id only; never invent provider
    return {
      modelOverride: String(ops.default_model),
      rail: null,
      skill: skillHint,
      reason: "manual_pin",
      cleanedPreview: cleaned.slice(0, 120),
    };
  }

  if (!rail) {
    // Fail closed to Auto router — NOT Opus / raw anthropic
    return {
      modelOverride: defaultModel,
      rail: "auto",
      skill: skillHint,
      reason,
      cleanedPreview: cleaned.slice(0, 120),
    };
  }

  const tiers = opts.healthTiers || {};
  const tierKey = rail === "free" ? "low" : rail;
  const fromHealth = tiers[tierKey] && tiers[tierKey].model;
  if (fromHealth && isYbSafeModelId(fromHealth)) {
    return {
      modelOverride: fromHealth,
      rail,
      skill: skillHint,
      reason: reason + "+health",
      cleanedPreview: cleaned.slice(0, 120),
    };
  }

  // No health / unsafe id → Auto router (fail closed)
  return {
    modelOverride: defaultModel,
    rail: "auto",
    skill: skillHint,
    reason: reason + "+fallback_auto",
    cleanedPreview: cleaned.slice(0, 120),
  };
}

/** Allow YB router ids and catalog ids.
 * Block bare claude-/gpt- without provider prefix.
 * Catalog ids like anthropic/claude-sonnet-4.6 are OK when health returns them.
 */
export function isYbSafeModelId(id) {
  if (!id || typeof id !== "string") return false;
  const s = id.trim();
  if (!s) return false;
  // reject bare anthropic model names without provider prefix
  if (/^claude-/i.test(s) || /^gpt-/i.test(s) || /^o[0-9]/i.test(s)) return false;
  // reject empty provider
  if (!s.includes("/") && !s.startsWith("yieldingbear")) return false;
  return true;
}

export function mergeHealthTiers(healthJson) {
  const tiers = (healthJson && healthJson.tiers) || {};
  const out = {};
  for (const k of ["high", "mid", "low"]) {
    if (tiers[k] && tiers[k].model) out[k] = { model: String(tiers[k].model) };
  }
  return out;
}
