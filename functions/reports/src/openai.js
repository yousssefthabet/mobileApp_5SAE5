"use strict";

const logger = require("firebase-functions/logger");
const { SYSTEM_PROMPT, RESPONSE_SCHEMA, buildUserText } = require("./prompt");

const API = "https://api.openai.com/v1";
const MODERATION_MODEL = "omni-moderation-latest";

/** Detects the image type from the first bytes of the base64 data. */
function dataUrl(base64) {
  let mime = "image/jpeg";
  if (base64.startsWith("iVBOR")) mime = "image/png";
  else if (base64.startsWith("UklGR")) mime = "image/webp";
  else if (base64.startsWith("R0lGOD")) mime = "image/gif";
  return `data:${mime};base64,${base64}`;
}

class OpenAIError extends Error {
  constructor(status, body) {
    const msg = body && body.error && body.error.message ? body.error.message : `HTTP ${status}`;
    super(msg);
    this.status = status;
    this.code = body && body.error ? body.error.code : undefined;
  }
}

async function post(path, apiKey, payload, timeoutMs) {
  const res = await fetch(`${API}${path}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(timeoutMs),
  });
  let body = null;
  try {
    body = await res.json();
  } catch (_) {
    // non-JSON error body
  }
  if (!res.ok) throw new OpenAIError(res.status, body);
  return body;
}

/**
 * Runs omni-moderation-latest on the text and on each photo (one request per
 * photo). Failures are collected instead of thrown so one failed call never
 * blocks a citizen's report.
 */
async function moderate(apiKey, { text, images }) {
  const errors = [];

  const textCall = post("/moderations", apiKey, { model: MODERATION_MODEL, input: text }, 20000)
    .then((r) => r.results[0])
    .catch((e) => {
      logger.warn("Text moderation failed", { message: e.message });
      errors.push("text");
      return null;
    });

  const imageCalls = images.map((b64, i) =>
    post(
      "/moderations",
      apiKey,
      { model: MODERATION_MODEL, input: [{ type: "image_url", image_url: { url: dataUrl(b64) } }] },
      30000,
    )
      .then((r) => r.results[0])
      .catch((e) => {
        logger.warn("Image moderation failed", { index: i, message: e.message });
        errors.push(`image ${i + 1}`);
        return null;
      }),
  );

  const [textResult, ...imageResults] = await Promise.all([textCall, ...imageCalls]);
  return { text: textResult, images: imageResults, errors };
}

function isModelUnavailable(err) {
  return (
    err instanceof OpenAIError &&
    (err.code === "model_not_found" ||
      err.status === 404 ||
      (err.status === 400 && /model/i.test(err.message) && /(does not exist|not found|not supported|access)/i.test(err.message)))
  );
}

/**
 * Asks the vision model to check the photos and write the professional report.
 * Tries each model in order and moves on only if a model is unavailable.
 * @returns {{model: string, result: object}}
 */
async function analyzeWithVision(apiKey, models, input) {
  const content = [
    { type: "text", text: buildUserText({ ...input, imageCount: input.images.length }) },
    ...input.images.map((b64) => ({
      type: "image_url",
      image_url: { url: dataUrl(b64), detail: "auto" },
    })),
  ];

  let lastError;
  for (const model of models) {
    const payload = {
      model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "municipal_report_analysis", strict: true, schema: RESPONSE_SCHEMA },
      },
      max_completion_tokens: 8000,
    };
    // GPT-5 family models are reasoning models; keep their thinking short.
    if (/^gpt-5/.test(model)) payload.reasoning_effort = "low";

    try {
      const body = await post("/chat/completions", apiKey, payload, 90000);
      const choice = body.choices && body.choices[0];
      const message = choice && choice.message;
      if (!message || message.refusal) {
        throw new Error(`Model refused: ${message ? message.refusal : "no message"}`);
      }
      if (choice.finish_reason === "length") {
        throw new Error("Model output was cut off (token limit)");
      }
      return { model, result: JSON.parse(message.content) };
    } catch (err) {
      lastError = err;
      if (isModelUnavailable(err)) {
        logger.warn(`Model ${model} unavailable, trying next`, { message: err.message });
        continue;
      }
      throw err;
    }
  }
  throw lastError || new Error("No vision model configured");
}

module.exports = { moderate, analyzeWithVision, MODERATION_MODEL };
