import { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  computePrice,
  numberOf,
  resolveConnector,
  validateWindow,
  checkModifiable,
} from "../domain";
import {
  isConnectorFree,
  listUserReservations,
  ReservationResult,
  searchAvailableChargersCore,
} from "../reservations";
import { detectLang } from "./nlu_rules";
import { Key, t } from "./i18n";
import { clampOffset, formatLocal, isValidDate, isValidTime, localToUtcMs } from "./time";
import {
  ChatAction,
  ChatContext,
  ChatRequest,
  ChatResponse,
  ChatState,
  InfoTopic,
  Lang,
  PendingAction,
  ReservationSummary,
  Understanding,
} from "./types";

/**
 * The dialogue engine. It turns an Understanding + the conversation state into
 * a reply, using real Firestore data. It only READS data: every write is
 * proposed as a `pending` action that the user must confirm in the app, which
 * then calls the transactional booking functions.
 */

export type Nlu = (
  text: string,
  nowMs: number,
  offsetMin: number,
) => Promise<{ understanding: Understanding; engine: "rules" | "llm" }>;

export interface DialogDeps {
  db: Firestore;
  nlu: Nlu;
  now?: () => Date;
}

const MIN = 60 * 1000;
const NEW_INTENTS = new Set(["find", "book", "list", "cancel", "reschedule"]);

// ---------------------------------------------------------------------------
// Input sanitising (state and context come from the client)
// ---------------------------------------------------------------------------

function cleanId(v: unknown): string | undefined {
  return typeof v === "string" && v.length > 0 && v.length <= 128 && !v.includes("/") ? v : undefined;
}

export function sanitizeState(raw: unknown): ChatState {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const s: ChatState = {};
  if (typeof r["intent"] === "string" && ["find", "book", "list", "cancel", "reschedule"].includes(r["intent"])) {
    s.intent = r["intent"] as ChatState["intent"];
  }
  if (typeof r["date"] === "string" && isValidDate(r["date"])) s.date = r["date"];
  if (typeof r["time"] === "string" && isValidTime(r["time"])) s.time = r["time"];
  const d = numberOf(r["durationMinutes"], NaN);
  if (Number.isInteger(d) && d > 0 && d <= 24 * 60) s.durationMinutes = d;
  s.chargerId = cleanId(r["chargerId"]);
  const c = numberOf(r["connectorId"], NaN);
  if (Number.isInteger(c)) s.connectorId = c;
  s.reservationId = cleanId(r["reservationId"]);
  if (r["lang"] === "fr" || r["lang"] === "en") s.lang = r["lang"];
  return Object.fromEntries(Object.entries(s).filter(([, v]) => v !== undefined)) as ChatState;
}

function sanitizeContext(raw: unknown): { offset: number; lat?: number; lng?: number } {
  const r = (raw && typeof raw === "object" ? raw : {}) as Partial<ChatContext>;
  const offset = clampOffset(r.tzOffsetMinutes);
  const lat = numberOf(r.lat, NaN);
  const lng = numberOf(r.lng, NaN);
  const ok = Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;
  return ok ? { offset, lat, lng } : { offset };
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function summarize(r: ReservationResult): ReservationSummary {
  return { ...r };
}

function mergeState(state: ChatState, u: Understanding, lang: Lang): ChatState {
  let next: ChatState = { ...state, lang };
  if (NEW_INTENTS.has(u.intent)) {
    if (u.intent !== state.intent) {
      next = { lang, intent: u.intent as ChatState["intent"] };
    }
  }
  if (u.date) next.date = u.date;
  if (u.time) next.time = u.time;
  if (u.durationMinutes !== undefined) next.durationMinutes = u.durationMinutes;
  return next;
}

function whenText(lang: Lang, date: string, time: string): string {
  return t(lang, "forWhen", { date, time });
}

function quickMenu(lang: Lang): string[] {
  return [
    t(lang, "qrFind"),
    t(lang, "qrBook"),
    t(lang, "qrList"),
    t(lang, "qrCancel"),
    t(lang, "qrResched"),
    t(lang, "qrNearest"),
  ];
}

function response(
  lang: Lang,
  engine: ChatResponse["engine"],
  state: ChatState,
  reply: string,
  extra: Partial<Pick<ChatResponse, "cards" | "pending" | "quickReplies" | "needsLocation">> = {},
): ChatResponse {
  return {
    reply,
    state: { ...state, lang },
    cards: extra.cards ?? [],
    pending: extra.pending,
    quickReplies: extra.quickReplies ?? [],
    needsLocation: extra.needsLocation,
    engine,
  };
}

function isUpcoming(r: ReservationResult, nowMs: number): boolean {
  return checkModifiable(r.status, Date.parse(r.start), nowMs) === null;
}

const WINDOW_KEY = { invalid_duration: "badDuration", start_in_past: "startPast", start_too_far: "startFar" } as const;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export async function handleTurn(
  deps: DialogDeps,
  uid: string | undefined,
  req: ChatRequest,
): Promise<ChatResponse> {
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in to continue.");

  const now = (deps.now ?? (() => new Date()))();
  const nowMs = now.getTime();
  const state = sanitizeState(req.state);
  const ctx = sanitizeContext(req.context);

  const text = typeof req.text === "string" ? req.text.slice(0, 500) : "";
  const lang = detectLang(text, state.lang);

  if (req.action) {
    return handleAction(deps, uid, req.action, state, ctx, lang, nowMs, now);
  }

  if (text.trim() === "") {
    return response(lang, "rules", state, t(lang, "welcome"), { quickReplies: quickMenu(lang) });
  }

  const { understanding: u, engine } = await deps.nlu(text, nowMs, ctx.offset);

  // Informational / greeting / unclear messages do not disturb a booking in progress.
  if (u.intent === "greeting") {
    return response(lang, engine, state, t(lang, "welcome"), { quickReplies: quickMenu(lang) });
  }
  if (u.intent === "info") {
    return answerInfo(deps.db, lang, engine, state, u.infoTopic ?? "how_it_works");
  }
  if (u.intent === "unknown" && !state.intent) {
    return response(lang, engine, {}, t(lang, "help"), { quickReplies: quickMenu(lang) });
  }

  const next = mergeState(state, u, lang);
  const intent = next.intent!;

  switch (intent) {
    case "find":
      return doFind(deps, uid, u, next, ctx, lang, engine, now);
    case "book":
      return doBook(deps, uid, next, ctx, lang, engine, now);
    case "list":
      return doList(deps, uid, u, next, lang, engine, nowMs);
    case "cancel":
      return doCancel(deps, uid, next, lang, engine, nowMs, ctx.offset, u);
    case "reschedule":
      return doReschedule(deps, uid, next, ctx, lang, engine, now);
    default:
      return response(lang, engine, {}, t(lang, "help"), { quickReplies: quickMenu(lang) });
  }
}

// ---------------------------------------------------------------------------
// Find
// ---------------------------------------------------------------------------

async function doFind(
  deps: DialogDeps,
  uid: string,
  u: Understanding,
  state: ChatState,
  ctx: ReturnType<typeof sanitizeContext>,
  lang: Lang,
  engine: ChatResponse["engine"],
  now: Date,
): Promise<ChatResponse> {
  if (u.nearMe && ctx.lat === undefined) {
    return response(lang, engine, state, t(lang, "needLocation"), { needsLocation: true });
  }

  let windowArgs: { start?: string; durationMinutes?: number } = {};
  let when = "";
  if (state.date && state.time) {
    const startMs = localToUtcMs(state.date, state.time, ctx.offset);
    const minutes = state.durationMinutes ?? 60;
    const err = validateWindow(startMs, minutes, now.getTime());
    if (err) {
      return response(lang, engine, { lang }, t(lang, WINDOW_KEY[err]), { quickReplies: quickMenu(lang) });
    }
    windowArgs = { start: new Date(startMs).toISOString(), durationMinutes: minutes };
    when = " " + whenText(lang, state.date, state.time);
  }

  const items = await searchAvailableChargersCore(
    deps.db,
    uid,
    { lat: ctx.lat, lng: ctx.lng, limit: 5, ...windowArgs },
    now,
  );
  const done: ChatState = { lang };
  if (items.length === 0) {
    return response(lang, engine, done, t(lang, "noChargers", { when }), { quickReplies: quickMenu(lang) });
  }
  return response(lang, engine, done, t(lang, "foundChargers", { n: items.length, when }), {
    cards: [{ type: "chargers", items, selectable: false }],
    quickReplies: [t(lang, "qrBook"), t(lang, "qrList")],
  });
}

// ---------------------------------------------------------------------------
// Book
// ---------------------------------------------------------------------------

async function doBook(
  deps: DialogDeps,
  uid: string,
  state: ChatState,
  ctx: ReturnType<typeof sanitizeContext>,
  lang: Lang,
  engine: ChatResponse["engine"],
  now: Date,
): Promise<ChatResponse> {
  if (!state.date) {
    return response(lang, engine, state, t(lang, "askDate"), {
      quickReplies: [t(lang, "qrToday"), t(lang, "qrTomorrow")],
    });
  }
  if (!state.time) return response(lang, engine, state, t(lang, "askTime"));
  if (state.durationMinutes === undefined) {
    return response(lang, engine, state, t(lang, "askDuration"), {
      quickReplies: [t(lang, "qr30"), t(lang, "qr60"), t(lang, "qr120")],
    });
  }

  const startMs = localToUtcMs(state.date, state.time, ctx.offset);
  const err = validateWindow(startMs, state.durationMinutes, now.getTime());
  if (err) {
    const cleared: ChatState = { ...state };
    if (err === "invalid_duration") delete cleared.durationMinutes;
    else {
      delete cleared.date;
      delete cleared.time;
    }
    return response(lang, engine, cleared, t(lang, WINDOW_KEY[err]));
  }

  return proposeChargers(deps, uid, state, ctx, lang, engine, now, "chooseCharger");
}

async function proposeChargers(
  deps: DialogDeps,
  uid: string,
  state: ChatState,
  ctx: ReturnType<typeof sanitizeContext>,
  lang: Lang,
  engine: ChatResponse["engine"],
  now: Date,
  messageKey: Key,
): Promise<ChatResponse> {
  const startMs = localToUtcMs(state.date!, state.time!, ctx.offset);
  const when = whenText(lang, state.date!, state.time!);
  const items = await searchAvailableChargersCore(
    deps.db,
    uid,
    {
      lat: ctx.lat,
      lng: ctx.lng,
      start: new Date(startMs).toISOString(),
      durationMinutes: state.durationMinutes,
      limit: 5,
    },
    now,
  );
  if (items.length === 0) {
    const cleared: ChatState = { ...state };
    delete cleared.time;
    return response(lang, engine, cleared, t(lang, "noneAvailable", { when }));
  }
  const kept: ChatState = { ...state };
  delete kept.chargerId;
  delete kept.connectorId;
  return response(lang, engine, kept, t(lang, messageKey, { when }), {
    cards: [{ type: "chargers", items, selectable: true }],
  });
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

async function doList(
  deps: DialogDeps,
  uid: string,
  u: Understanding,
  state: ChatState,
  lang: Lang,
  engine: ChatResponse["engine"],
  nowMs: number,
): Promise<ChatResponse> {
  const all = await listUserReservations(deps.db, uid);
  const done: ChatState = { lang };
  if (u.includeAll) {
    const recent = all.slice().reverse().slice(0, 10);
    if (recent.length === 0) return response(lang, engine, done, t(lang, "listNone"), { quickReplies: quickMenu(lang) });
    return response(lang, engine, done, t(lang, "listAll", { n: recent.length }), {
      cards: [{ type: "reservations", items: recent.map(summarize) }],
    });
  }
  const upcoming = all.filter((r) => isUpcoming(r, nowMs) || (r.status === "confirmed" && Date.parse(r.end) > nowMs));
  if (upcoming.length === 0) {
    return response(lang, engine, done, t(lang, "listNone"), { quickReplies: [t(lang, "qrBook"), t(lang, "qrFind")] });
  }
  return response(lang, engine, done, t(lang, "listUpcoming", { n: upcoming.length }), {
    cards: [{ type: "reservations", items: upcoming.slice(0, 10).map(summarize) }],
    quickReplies: [t(lang, "qrCancel"), t(lang, "qrResched")],
  });
}

// ---------------------------------------------------------------------------
// Cancel
// ---------------------------------------------------------------------------

function reservationLines(lang: Lang, r: ReservationResult, offset: number) {
  const s = formatLocal(Date.parse(r.start), offset);
  return [
    { label: t(lang, "lblStation"), value: r.stationName },
    { label: t(lang, "lblConnector"), value: r.connectorName },
    { label: t(lang, "lblDate"), value: s.date },
    { label: t(lang, "lblTime"), value: s.time },
    { label: t(lang, "lblDuration"), value: t(lang, "minutes", { n: r.durationMinutes }) },
  ];
}

async function doCancel(
  deps: DialogDeps,
  uid: string,
  state: ChatState,
  lang: Lang,
  engine: ChatResponse["engine"],
  nowMs: number,
  offset: number,
  u: Understanding,
): Promise<ChatResponse> {
  const all = (await listUserReservations(deps.db, uid)).filter((r) => isUpcoming(r, nowMs));
  if (all.length === 0) return response(lang, engine, { lang }, t(lang, "cancelNone"), { quickReplies: quickMenu(lang) });

  let candidates = all;
  if (u.date || u.time) {
    const narrowed = all.filter((r) => {
      const s = formatLocal(Date.parse(r.start), offset);
      return (!u.date || s.date === u.date) && (!u.time || s.time.slice(0, 2) === u.time.slice(0, 2));
    });
    if (narrowed.length > 0) candidates = narrowed;
  }

  if (candidates.length === 1) return pendingCancel(lang, engine, state, candidates[0], offset);
  return response(lang, engine, { lang, intent: "cancel" }, t(lang, "cancelPick"), {
    cards: [{ type: "reservations", items: candidates.slice(0, 10).map(summarize), selectable: "cancel" }],
  });
}

function pendingCancel(
  lang: Lang,
  engine: ChatResponse["engine"],
  state: ChatState,
  r: ReservationResult,
  offset: number,
): ChatResponse {
  const pending: PendingAction = {
    kind: "cancel",
    params: { reservationId: r.id },
    summary: reservationLines(lang, r, offset),
  };
  return response(lang, engine, { ...state, intent: "cancel", reservationId: r.id }, t(lang, "confirmCancel"), { pending });
}

// ---------------------------------------------------------------------------
// Reschedule
// ---------------------------------------------------------------------------

async function doReschedule(
  deps: DialogDeps,
  uid: string,
  state: ChatState,
  ctx: ReturnType<typeof sanitizeContext>,
  lang: Lang,
  engine: ChatResponse["engine"],
  now: Date,
): Promise<ChatResponse> {
  const nowMs = now.getTime();
  const targets = (await listUserReservations(deps.db, uid)).filter((r) => isUpcoming(r, nowMs));
  if (targets.length === 0) return response(lang, engine, { lang }, t(lang, "reschedNone"), { quickReplies: quickMenu(lang) });

  const target =
    targets.find((r) => r.id === state.reservationId) ?? (targets.length === 1 ? targets[0] : undefined);
  if (!target) {
    const kept: ChatState = { ...state };
    delete kept.reservationId;
    return response(lang, engine, kept, t(lang, "reschedPick"), {
      cards: [{ type: "reservations", items: targets.slice(0, 10).map(summarize), selectable: "reschedule" }],
    });
  }

  const withTarget: ChatState = { ...state, reservationId: target.id };
  if (!state.date && !state.time) return response(lang, engine, withTarget, t(lang, "reschedAsk"));

  const current = formatLocal(Date.parse(target.start), ctx.offset);
  const newDate = state.date ?? current.date;
  const newTime = state.time ?? current.time;
  const minutes = state.durationMinutes ?? target.durationMinutes;
  const startMs = localToUtcMs(newDate, newTime, ctx.offset);

  const cleared = (): ChatState => {
    const c = { ...withTarget };
    delete c.date;
    delete c.time;
    delete c.durationMinutes;
    return c;
  };

  if (startMs === Date.parse(target.start) && minutes === target.durationMinutes) {
    return response(lang, engine, cleared(), t(lang, "reschedSame"));
  }
  const err = validateWindow(startMs, minutes, nowMs);
  if (err) return response(lang, engine, cleared(), t(lang, WINDOW_KEY[err]));

  const endMs = startMs + minutes * MIN;
  const free = await isConnectorFree(deps.db, target.chargerId, String(target.connectorId), startMs, endMs, target.id);
  if (!free) return response(lang, engine, cleared(), t(lang, "reschedBusy"));

  const chargerSnap = await deps.db.collection("ev_chargers").doc(target.chargerId).get();
  let amount = target.amount;
  if (chargerSnap.exists) {
    const charger = chargerSnap.data() as Record<string, unknown>;
    const resolved = resolveConnector(charger["connectors"], target.connectorId);
    if (resolved) amount = computePrice(charger, resolved.connector, minutes).total;
  }

  const pending: PendingAction = {
    kind: "reschedule",
    params: { reservationId: target.id, start: new Date(startMs).toISOString(), durationMinutes: minutes },
    summary: [
      { label: t(lang, "lblStation"), value: target.stationName },
      { label: t(lang, "lblConnector"), value: target.connectorName },
      { label: t(lang, "lblFrom"), value: `${current.date} ${current.time}` },
      { label: t(lang, "lblTo"), value: `${newDate} ${newTime}` },
      { label: t(lang, "lblDuration"), value: t(lang, "minutes", { n: minutes }) },
      { label: t(lang, "lblPrice"), value: `${amount.toFixed(2)} ${target.currency}` },
    ],
    amount,
    currency: target.currency,
  };
  return response(lang, engine, { ...withTarget, date: newDate, time: newTime, durationMinutes: minutes }, t(lang, "confirmReschedule"), { pending });
}

// ---------------------------------------------------------------------------
// Card selections (structured actions, no NLU)
// ---------------------------------------------------------------------------

async function handleAction(
  deps: DialogDeps,
  uid: string,
  action: ChatAction,
  state: ChatState,
  ctx: ReturnType<typeof sanitizeContext>,
  lang: Lang,
  nowMs: number,
  now: Date,
): Promise<ChatResponse> {
  const engine = "rules" as const;

  if (action.type === "select_connector") {
    const chargerId = cleanId(action.chargerId);
    if (state.intent !== "book" || !state.date || !state.time || state.durationMinutes === undefined || !chargerId) {
      return response(lang, engine, { lang }, t(lang, "help"), { quickReplies: quickMenu(lang) });
    }
    const startMs = localToUtcMs(state.date, state.time, ctx.offset);
    const minutes = state.durationMinutes;
    if (validateWindow(startMs, minutes, nowMs)) {
      return response(lang, engine, { lang }, t(lang, "startPast"), { quickReplies: quickMenu(lang) });
    }
    const endMs = startMs + minutes * MIN;
    const snap = await deps.db.collection("ev_chargers").doc(chargerId).get();
    const charger = snap.exists ? (snap.data() as Record<string, unknown>) : undefined;
    const resolved = charger && charger["isActive"] !== false ? resolveConnector(charger["connectors"], action.connectorId) : null;
    const physicallyFree = resolved && String(resolved.connector["status"] ?? "free").toLowerCase() === "free";
    const free = resolved && physicallyFree && (await isConnectorFree(deps.db, chargerId, resolved.key, startMs, endMs));
    if (!charger || !resolved || !free) {
      return proposeChargers(deps, uid, state, ctx, lang, engine, now, "slotGone");
    }

    const price = computePrice(charger, resolved.connector, minutes);
    const stationName = String(charger["name"] ?? charger["stationName"] ?? "Charging station");
    const connectorName = String(resolved.connector["name"] ?? resolved.connector["type"] ?? `Connector ${resolved.key}`);
    const pending: PendingAction = {
      kind: "create",
      params: { chargerId, connectorId: Number(resolved.key), start: new Date(startMs).toISOString(), durationMinutes: minutes },
      summary: [
        { label: t(lang, "lblStation"), value: stationName },
        { label: t(lang, "lblConnector"), value: connectorName },
        { label: t(lang, "lblDate"), value: state.date },
        { label: t(lang, "lblTime"), value: state.time },
        { label: t(lang, "lblDuration"), value: t(lang, "minutes", { n: minutes }) },
        { label: t(lang, "lblPrice"), value: `${price.total.toFixed(2)} TND` },
      ],
      amount: price.total,
      currency: "TND",
    };
    return response(lang, engine, { ...state, chargerId, connectorId: Number(resolved.key) }, t(lang, "confirmCreate"), { pending });
  }

  if (action.type === "select_reservation") {
    const id = cleanId(action.reservationId);
    const mine = (await listUserReservations(deps.db, uid)).filter((r) => isUpcoming(r, nowMs));
    const target = mine.find((r) => r.id === id);
    if (!target || (state.intent !== "cancel" && state.intent !== "reschedule")) {
      return response(lang, engine, { lang }, t(lang, "cancelNone"), { quickReplies: quickMenu(lang) });
    }
    if (state.intent === "cancel") return pendingCancel(lang, engine, state, target, ctx.offset);
    return doReschedule(deps, uid, { ...state, reservationId: target.id }, ctx, lang, engine, now);
  }

  return response(lang, engine, { lang }, t(lang, "help"), { quickReplies: quickMenu(lang) });
}

// ---------------------------------------------------------------------------
// Info (answers come from real station data and the real booking rules)
// ---------------------------------------------------------------------------

async function answerInfo(
  db: Firestore,
  lang: Lang,
  engine: ChatResponse["engine"],
  state: ChatState,
  topic: InfoTopic,
): Promise<ChatResponse> {
  const menu = { quickReplies: [t(lang, "qrBook"), t(lang, "qrFind")] };
  const kept = state;

  if (topic === "conditions") return response(lang, engine, kept, t(lang, "infoConditions"), menu);
  if (topic === "statuses") return response(lang, engine, kept, t(lang, "infoStatuses"), menu);
  if (topic === "how_it_works") return response(lang, engine, kept, t(lang, "infoHow"), menu);

  const snap = await db.collection("ev_chargers").where("isActive", "==", true).get();
  const chargers = snap.docs.map((d) => d.data());

  if (topic === "pricing") {
    const prices = chargers
      .map((c) => numberOf(c["pricePerKwh"] ?? c["price_per_kwh"] ?? c["price"], NaN))
      .filter((p) => Number.isFinite(p) && p > 0);
    if (prices.length === 0) return response(lang, engine, kept, t(lang, "infoPricingNone"), menu);
    const fees = chargers.map((c) => numberOf(c["reservationFee"] ?? c["reservation_fee"])).filter((f) => f > 0);
    const fee =
      fees.length > 0
        ? (lang === "fr" ? `, plus des frais de réservation de ${Math.min(...fees)} à ${Math.max(...fees)} TND` : `, plus a reservation fee of ${Math.min(...fees)} to ${Math.max(...fees)} TND`)
        : "";
    return response(lang, engine, kept, t(lang, "infoPricing", { min: Math.min(...prices), max: Math.max(...prices), fee }), menu);
  }

  const connectors = chargers.flatMap((c) => (Array.isArray(c["connectors"]) ? (c["connectors"] as Record<string, unknown>[]) : []));
  if (topic === "connectors") {
    const types = [...new Set(connectors.map((c) => c["type"]).filter((x): x is string => typeof x === "string" && x.trim() !== ""))].sort();
    return response(lang, engine, kept, types.length ? t(lang, "infoConnectors", { list: types.join(", ") }) : t(lang, "infoConnectorsNone"), menu);
  }
  const powers = [...new Set(connectors.map((c) => numberOf(c["power"], NaN)).filter((p) => Number.isFinite(p) && p > 0))].sort((a, b) => a - b);
  return response(lang, engine, kept, powers.length ? t(lang, "infoPower", { list: powers.join(", ") }) : t(lang, "infoPowerNone"), menu);
}
