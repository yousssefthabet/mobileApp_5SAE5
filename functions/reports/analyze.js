"use strict";

/**
 * Chargi Cloud Functions (2nd gen).
 *
 * analyzeReport: callable function used by the report form before saving.
 *  1. Safety moderation of the text and every photo (omni-moderation-latest).
 *  2. Vision model: photo relevance / quality / consistency check and a
 *     professional report for municipal workers.
 *  3. Deterministic rules combine both into APPROVED / NEEDS_REVIEW / REJECTED.
 *
 * The OpenAI key is read from Secret Manager (secret OPENAI_API_KEY) and is
 * never sent to the app.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const { moderate, analyzeWithVision, MODERATION_MODEL } = require("./src/openai");
const { combine } = require("./src/decision");

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// Must match the region used in lib/services/report_ai_service.dart.
const REGION = "europe-west1";

const MAX_IMAGES = 4;
const MAX_IMAGE_BASE64_CHARS = 1_500_000; // ~1.1 MB per photo
const MAX_TITLE = 200;
const MAX_DESCRIPTION = 2000;

function visionModels() {
  const preferred = (process.env.OPENAI_VISION_MODEL || "gpt-5.4-mini").trim();
  const fallbacks = (process.env.OPENAI_FALLBACK_MODELS || "gpt-5-mini,gpt-4.1-mini")
    .split(",")
    .map((m) => m.trim())
    .filter(Boolean);
  return [...new Set([preferred, ...fallbacks])];
}

function cleanString(value, max, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `"${field}" is required.`);
  }
  return value.trim().slice(0, max);
}

function validate(data) {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Missing request data.");
  }
  const title = cleanString(data.title, MAX_TITLE, "title");
  const description = cleanString(data.description, MAX_DESCRIPTION, "description");

  const images = data.images;
  if (!Array.isArray(images) || images.length === 0) {
    throw new HttpsError("invalid-argument", "At least one photo is required.");
  }
  if (images.length > MAX_IMAGES) {
    throw new HttpsError("invalid-argument", `At most ${MAX_IMAGES} photos are allowed.`);
  }
  images.forEach((img, i) => {
    if (typeof img !== "string" || img.length < 100 || !/^[A-Za-z0-9+/=]+$/.test(img.slice(0, 200))) {
      throw new HttpsError("invalid-argument", `Photo ${i + 1} is not valid base64 image data.`);
    }
    if (img.length > MAX_IMAGE_BASE64_CHARS) {
      throw new HttpsError("invalid-argument", `Photo ${i + 1} is too large.`);
    }
  });

  const loc = data.location && typeof data.location === "object" ? data.location : {};
  const location = {
    address: typeof loc.address === "string" ? loc.address.slice(0, 300) : "",
    landmark: typeof loc.landmark === "string" ? loc.landmark.slice(0, 200) : "",
    latitude: typeof loc.latitude === "number" ? loc.latitude : undefined,
    longitude: typeof loc.longitude === "number" ? loc.longitude : undefined,
  };

  return { title, description, images, location };
}

exports.analyzeReport = onCall(
  {
    region: REGION,
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10, // cost protection
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in to analyze a report.");
    }

    const input = validate(request.data);
    const apiKey = OPENAI_API_KEY.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "The AI service is not configured.");
    }

    const started = Date.now();
    const text = `Title: ${input.title}\nDescription: ${input.description}`;

    // Moderation and vision run in parallel; neither failure throws.
    const [moderation, vision] = await Promise.all([
      moderate(apiKey, { text, images: input.images }),
      analyzeWithVision(apiKey, visionModels(), input).catch((err) => {
        logger.error("Vision analysis failed", { message: err.message, uid: request.auth.uid });
        return null;
      }),
    ]);

    const analysis = vision ? vision.result.image_analysis : null;
    const decision = combine(moderation, analysis);

    logger.info("Report analyzed", {
      uid: request.auth.uid,
      status: decision.status,
      model: vision ? vision.model : null,
      images: input.images.length,
      moderationFlags: decision.moderationCategories,
      ms: Date.now() - started,
    });

    return {
      status: decision.status, // APPROVED | NEEDS_REVIEW | REJECTED
      explanation: decision.explanation,
      reasons: decision.reasons,
      moderation: {
        model: MODERATION_MODEL,
        flaggedCategories: decision.moderationCategories,
        incomplete: moderation.errors.length > 0,
      },
      imageAnalysis: analysis,
      // When rejected, no report is generated for the workers.
      report: vision && decision.status !== "REJECTED" ? vision.result.report : null,
      model: vision ? vision.model : null,
      analyzedAt: new Date().toISOString(),
      disclaimer:
        "AI analysis is an aid for triage only. It is not proof that an incident occurred.",
    };
  },
);
