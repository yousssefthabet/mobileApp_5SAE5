import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onCall } from "firebase-functions/v2/https";

import { handleTurn } from "./chatbot/dialog";
import { buildNlu } from "./chatbot/engine";
import { consumeLlmQuota } from "./chatbot/quota";
import type { ChatRequest } from "./chatbot/types";

import {
  cancelReservationCore,
  createReservationCore,
  rescheduleReservationCore,
  searchAvailableChargersCore,
} from "./reservations";

initializeApp();
const db = getFirestore();

// Every function requires a signed-in user (checked inside the core too).
// App Check can be enforced here once it is configured in the app:
//   onCall({ enforceAppCheck: true }, ...)

export const createReservation = onCall(async (request) => {
  const data = (request.data ?? {}) as Record<string, unknown>;
  return createReservationCore(
    db,
    request.auth?.uid,
    request.auth?.token.email,
    {
      chargerId: data["chargerId"],
      connectorId: data["connectorId"],
      start: data["start"],
      durationMinutes: data["durationMinutes"],
      promoCode: data["promoCode"],
    },
  );
});

export const cancelReservation = onCall(async (request) => {
  const data = (request.data ?? {}) as Record<string, unknown>;
  return cancelReservationCore(db, request.auth?.uid, data["reservationId"]);
});

export const rescheduleReservation = onCall(async (request) => {
  const data = (request.data ?? {}) as Record<string, unknown>;
  return rescheduleReservationCore(db, request.auth?.uid, {
    reservationId: data["reservationId"],
    start: data["start"],
    durationMinutes: data["durationMinutes"],
  });
});

export const searchAvailableChargers = onCall(async (request) => {
  const data = (request.data ?? {}) as Record<string, unknown>;
  return searchAvailableChargersCore(db, request.auth?.uid, {
    lat: data["lat"],
    lng: data["lng"],
    start: data["start"],
    durationMinutes: data["durationMinutes"],
    radiusKm: data["radiusKm"],
    limit: data["limit"],
  });
});

// ---------------------------------------------------------------------------
// Chat assistant.
//
// Default: deterministic rule-based understanding (no external service).
// To use an LLM for understanding, set in functions/.env:
//   CHATBOT_USE_LLM=true            (optional: CHATBOT_MODEL=<model id>)
// and store the key as a secret (never in the Flutter app):
//   firebase functions:secrets:set ANTHROPIC_API_KEY
// The LLM only extracts intent and entities; it cannot run actions.
// ---------------------------------------------------------------------------
const useLlm = process.env["CHATBOT_USE_LLM"] === "true";
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

export const chatAssistant = onCall(
  { secrets: useLlm ? [anthropicKey] : [] },
  async (request) => {
    const uid = request.auth?.uid;
    const nlu = buildNlu({
      apiKey: useLlm ? anthropicKey.value() : undefined,
      // Per-user cap on LLM calls (cost/abuse); over the cap the rules answer.
      allowLlm: uid ? () => consumeLlmQuota(db, uid, Date.now()) : undefined,
      model: process.env["CHATBOT_MODEL"],
      log: (msg, err) => logger.warn(msg, { error: String(err) }),
    });
    return handleTurn({ db, nlu }, request.auth?.uid, (request.data ?? {}) as ChatRequest);
  },
);
