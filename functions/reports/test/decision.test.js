"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { combine } = require("../src/decision");

const cleanMod = { text: { categories: {} }, images: [{ categories: {} }], errors: [] };

const goodAnalysis = {
  recommended_status: "APPROVED",
  explanation: "The photo shows a streetlight that is not lit.",
  relevance: "relevant",
  image_quality: "clear",
  supports_reported_issue: "supports",
  content_concerns: [],
  suspicious_signals: [],
  per_image: [],
};

test("clean, relevant, clear photo is approved", () => {
  assert.equal(combine(cleanMod, goodAnalysis).status, "APPROVED");
});

test("sexual image is rejected even if the model approves", () => {
  const mod = { ...cleanMod, images: [{ categories: { sexual: true } }] };
  const r = combine(mod, goodAnalysis);
  assert.equal(r.status, "REJECTED");
  assert.match(r.explanation, /not allowed/);
});

test("graphic/violence flag goes to review, not rejection (e.g. accident scene)", () => {
  const mod = { ...cleanMod, images: [{ categories: { "violence/graphic": true } }] };
  assert.equal(combine(mod, goodAnalysis).status, "NEEDS_REVIEW");
});

test("hateful graffiti flagged as hate goes to review, not rejection", () => {
  const mod = { ...cleanMod, images: [{ categories: { hate: true } }] };
  assert.equal(combine(mod, goodAnalysis).status, "NEEDS_REVIEW");
});

test("model cannot reject a relevant hazard photo without content concerns", () => {
  const a = { ...goodAnalysis, recommended_status: "REJECTED", explanation: "Dangerous wires" };
  assert.equal(combine(cleanMod, a).status, "NEEDS_REVIEW");
});

test("model can reject an irrelevant photo", () => {
  const a = {
    ...goodAnalysis,
    recommended_status: "REJECTED",
    relevance: "irrelevant",
    explanation: "The photo shows a cat, not a municipal problem.",
  };
  const r = combine(cleanMod, a);
  assert.equal(r.status, "REJECTED");
  assert.match(r.explanation, /cat/);
});

test("blurry photo approved by the model is sent to review", () => {
  const a = { ...goodAnalysis, image_quality: "blurry" };
  const r = combine(cleanMod, a);
  assert.equal(r.status, "NEEDS_REVIEW");
  assert.match(r.explanation, /blurry/);
});

test("contradiction or suspicious signal is sent to review", () => {
  assert.equal(
    combine(cleanMod, { ...goodAnalysis, supports_reported_issue: "contradicts" }).status,
    "NEEDS_REVIEW",
  );
  assert.equal(
    combine(cleanMod, { ...goodAnalysis, suspicious_signals: ["screenshot of a screen"] }).status,
    "NEEDS_REVIEW",
  );
});

test("vision failure never blocks: needs review", () => {
  assert.equal(combine(cleanMod, null).status, "NEEDS_REVIEW");
});

test("moderation outage never blocks: needs review", () => {
  const mod = { text: null, images: [null], errors: ["image 1"] };
  assert.equal(combine(mod, goodAnalysis).status, "NEEDS_REVIEW");
});

test("angry but legitimate text (harassment flag) goes to review only", () => {
  const mod = { ...cleanMod, text: { categories: { harassment: true } } };
  assert.equal(combine(mod, goodAnalysis).status, "NEEDS_REVIEW");
});
