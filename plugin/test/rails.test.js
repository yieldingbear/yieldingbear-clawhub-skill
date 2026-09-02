import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  AUTO_ROUTER,
  isYbSafeModelId,
  mergeHealthTiers,
  selectModelOverride,
  stripEnvelope,
} from "../lib/rails.js";

describe("stripEnvelope", () => {
  it("strips slack-ish mention and finds skill", () => {
    const r = stripEnvelope("<@U123> Skill: github please review");
    assert.equal(r.skillHint, "github");
  });
  it("finds slash skill", () => {
    const r = stripEnvelope("/summarize this thread");
    assert.equal(r.skillHint, "summarize");
  });
});

describe("isYbSafeModelId", () => {
  it("allows yieldingbear router and catalog ids", () => {
    assert.equal(isYbSafeModelId("yieldingbear/grizzly-1.0g-pro"), true);
    assert.equal(isYbSafeModelId("anthropic/claude-sonnet-4.6"), true);
    assert.equal(isYbSafeModelId("google/gemini-2.5-flash"), true);
  });
  it("rejects bare frontier ids", () => {
    assert.equal(isYbSafeModelId("claude-opus-4"), false);
    assert.equal(isYbSafeModelId("gpt-4o"), false);
  });
});

describe("selectModelOverride", () => {
  const health = mergeHealthTiers({
    tiers: {
      high: { model: "anthropic/claude-sonnet-4.6" },
      mid: { model: "google/gemini-2.5-flash" },
      low: { model: "nvidia/nemotron-3-nano-30b" },
    },
  });

  it("defaults to Auto router", () => {
    const d = selectModelOverride({ prompt: "hello", healthTiers: health });
    assert.equal(d.modelOverride, AUTO_ROUTER);
    assert.equal(d.rail, "auto");
  });

  it("maps github skill to high via health", () => {
    const d = selectModelOverride({
      prompt: "Skill: github review this PR",
      healthTiers: health,
    });
    assert.equal(d.rail, "high");
    assert.equal(d.modelOverride, "anthropic/claude-sonnet-4.6");
  });

  it("maps summarize to free", () => {
    const d = selectModelOverride({
      prompt: "/summarize please",
      healthTiers: health,
    });
    assert.equal(d.rail, "free");
    assert.equal(d.modelOverride, "nvidia/nemotron-3-nano-30b");
  });

  it("fail closed to Auto when health missing for rail", () => {
    const d = selectModelOverride({
      prompt: "Skill: github",
      healthTiers: {},
    });
    assert.equal(d.modelOverride, AUTO_ROUTER);
    assert.match(d.reason, /fallback_auto/);
  });

  it("force free for circuit breaker", () => {
    const d = selectModelOverride({
      prompt: "Skill: github",
      healthTiers: health,
      forceFree: true,
    });
    assert.equal(d.rail, "free");
    assert.equal(d.modelOverride, "nvidia/nemotron-3-nano-30b");
  });

  it("never returns bare claude id", () => {
    const d = selectModelOverride({
      prompt: "Skill: github",
      healthTiers: mergeHealthTiers({
        tiers: { high: { model: "claude-opus-4" } },
      }),
    });
    assert.equal(d.modelOverride, AUTO_ROUTER);
  });
});
