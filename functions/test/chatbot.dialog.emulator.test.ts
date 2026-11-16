/**
 * End-to-end dialogue tests against the Firestore emulator: the assistant talks
 * to the real reservation logic. Run inside emulators:exec (see package.json).
 */
import { test, before, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";

import { handleTurn } from "../src/chatbot/dialog";
import { buildNlu } from "../src/chatbot/engine";
import { addDays, todayLocal } from "../src/chatbot/time";
import { ChatRequest, ChatResponse, ChatState } from "../src/chatbot/types";
import {
  cancelReservationCore,
  createReservationCore,
  rescheduleReservationCore,
} from "../src/reservations";

let db: Firestore;
const NOW = new Date();
const OFFSET = 0;
const CTX = { tzOffsetMinutes: OFFSET };
const TOMORROW = addDays(todayLocal(NOW.getTime(), OFFSET), 1);
const IN_3_DAYS = addDays(todayLocal(NOW.getTime(), OFFSET), 3);
const nlu = buildNlu({});

before(() => {
  assert.ok(process.env["FIRESTORE_EMULATOR_HOST"], "run inside emulators:exec");
  initializeApp({ projectId: "demo-chargi-chat" });
  db = getFirestore();
});

beforeEach(async () => {
  for (const name of ["reservations", "connector_locks", "notifications", "ev_chargers", "users"]) {
    await db.recursiveDelete(db.collection(name));
  }
  await db.collection("ev_chargers").doc("ch1").set({
    name: "Station One", isActive: true, latitude: 36.8, longitude: 10.18,
    pricePerKwh: 0.5, reservationFee: 1,
    connectors: [
      { connectorId: 1, type: "CCS", power: 50, status: "free" },
      { connectorId: 2, type: "Type 2", power: 22, status: "free" },
    ],
  });
  await db.collection("ev_chargers").doc("off").set({ name: "Off", isActive: false, connectors: [{ power: 7 }] });
});

const say = (uid: string | undefined, req: ChatRequest): Promise<ChatResponse> =>
  handleTurn({ db, nlu, now: () => NOW }, uid, { context: CTX, ...req });

const text = (uid: string, t: string, state?: ChatState) => say(uid, { text: t, state });

async function code(p: Promise<unknown>): Promise<string> {
  try { await p; return "ok"; } catch (e) { return (e as { code: string }).code; }
}

/** Books via the real server function, returning the reservation id. */
async function book(uid: string, connectorId: number, date: string, time: string, minutes = 60) {
  return createReservationCore(db, uid, undefined, {
    chargerId: "ch1", connectorId,
    start: new Date(`${date}T${time}:00.000Z`).toISOString(), durationMinutes: minutes,
  }, NOW);
}

test("welcome and menu on empty message and greeting", async () => {
  const a = await say("alice", {});
  assert.match(a.reply, /Chargi AI Assistant/);
  assert.ok(a.quickReplies.length >= 6);
  assert.match((await text("alice", "hello")).reply, /Chargi AI Assistant/);
  assert.match((await text("alice", "bonjour")).reply, /Je suis Chargi/);
});

test("unauthenticated users are refused", async () => {
  assert.equal(await code(say(undefined, { text: "hello" })), "unauthenticated");
});

test("multi-step booking: asks for what is missing, then confirms only on request", async () => {
  let r = await text("alice", "I want to book a charging station");
  assert.match(r.reply, /Which day/);
  assert.equal(r.pending, undefined);

  r = await text("alice", "tomorrow", r.state);
  assert.match(r.reply, /what time/i);

  r = await text("alice", "at 14:00", r.state);
  assert.match(r.reply, /how long/i);
  assert.ok(r.quickReplies.length === 3);

  r = await text("alice", "2 hours", r.state);
  assert.equal(r.cards[0].type, "chargers");
  assert.equal(r.pending, undefined); // nothing proposed until a connector is picked
  assert.equal((await db.collection("reservations").get()).size, 0);

  const picked = await say("alice", { action: { type: "select_connector", chargerId: "ch1", connectorId: 1 }, state: r.state });
  assert.equal(picked.pending?.kind, "create");
  assert.equal((await db.collection("reservations").get()).size, 0); // still nothing written
  if (picked.pending?.kind !== "create") throw new Error("expected create");
  assert.equal(picked.pending.amount, 51); // 50 kW * 2 h * 0.5 + 1
  assert.equal(picked.pending.params.start, `${TOMORROW}T14:00:00.000Z`);

  // The app calls the real function only after the user taps "Confirm".
  const created = await createReservationCore(db, "alice", undefined, picked.pending.params, NOW);
  assert.equal(created.status, "confirmed");
});

test("one-sentence booking goes straight to station choices (French works too)", async () => {
  const r = await text("alice", "Je veux réserver une borne demain à 14h pendant 1 heure");
  assert.equal(r.cards[0].type, "chargers");
  assert.equal(r.state.lang, "fr");
  assert.match(r.reply, /connecteur libre/);
  const c = r.cards[0];
  if (c.type !== "chargers") throw new Error();
  assert.deepEqual(c.items.map((i) => i.id), ["ch1"]); // inactive station hidden
});

test("a time that is already past is rejected with a clear message", async () => {
  const yesterday = addDays(todayLocal(NOW.getTime(), OFFSET), -1);
  const r = await text("alice", `book a station on ${yesterday} at 10:00 for 1 hour`);
  assert.match(r.reply, /already passed/);
  assert.equal(r.cards.length, 0);
});

test("no free connector: says so and does not invent options", async () => {
  await book("bob", 1, TOMORROW, "14:00");
  await book("carol", 2, TOMORROW, "14:00");
  const r = await text("alice", "book a station tomorrow at 14:00 for 1 hour");
  assert.match(r.reply, /No charger has a free connector/);
  assert.equal(r.cards.length, 0);
});

test("slot taken between proposal and confirmation: the server still refuses", async () => {
  const r = await text("alice", "book a station tomorrow at 14:00 for 1 hour");
  const picked = await say("alice", { action: { type: "select_connector", chargerId: "ch1", connectorId: 1 }, state: r.state });
  assert.equal(picked.pending?.kind, "create");
  if (picked.pending?.kind !== "create") throw new Error();

  await book("bob", 1, TOMORROW, "14:00"); // someone else wins the race
  assert.equal(await code(createReservationCore(db, "alice", undefined, picked.pending.params, NOW)), "already-exists");
  assert.equal((await db.collection("reservations").get()).size, 1);

  // Picking the now-taken connector again re-proposes alternatives instead.
  const again = await say("alice", { action: { type: "select_connector", chargerId: "ch1", connectorId: 1 }, state: r.state });
  assert.equal(again.pending, undefined);
  assert.match(again.reply, /no longer free/);
  assert.equal(again.cards[0].type, "chargers");
});

test("list: only my own upcoming reservations", async () => {
  await book("alice", 1, TOMORROW, "10:00");
  await book("bob", 2, TOMORROW, "10:00");
  const r = await text("alice", "Show me my upcoming reservations");
  const c = r.cards[0];
  if (c?.type !== "reservations") throw new Error("expected reservations card");
  assert.equal(c.items.length, 1);
  const bobs = await text("bob", "show my reservations");
  assert.equal((bobs.cards[0] as { items: unknown[] }).items.length, 1);
  assert.match((await text("carol", "show my reservations")).reply, /no upcoming/i);
});

test("cancel: narrows by date, asks to pick when ambiguous, needs confirmation", async () => {
  const a = await book("alice", 1, TOMORROW, "10:00");
  const b = await book("alice", 2, IN_3_DAYS, "10:00");

  let r = await text("alice", "Cancel my reservation for tomorrow");
  assert.equal(r.pending?.kind, "cancel");
  assert.deepEqual(r.pending?.params, { reservationId: a.id });
  assert.equal((await db.collection("reservations").doc(a.id).get()).get("status"), "confirmed"); // not yet

  r = await text("alice", "cancel my reservation");
  assert.equal(r.pending, undefined);
  const card = r.cards[0];
  if (card?.type !== "reservations") throw new Error();
  assert.equal(card.selectable, "cancel");
  assert.equal(card.items.length, 2);

  const chosen = await say("alice", { action: { type: "select_reservation", reservationId: b.id }, state: r.state });
  assert.equal(chosen.pending?.kind, "cancel");
  if (chosen.pending?.kind !== "cancel") throw new Error();
  await cancelReservationCore(db, "alice", chosen.pending.params.reservationId, NOW);
  assert.equal((await db.collection("reservations").doc(b.id).get()).get("status"), "cancelled");
});

test("cancel: nothing to cancel, and other people's reservations are untouchable", async () => {
  assert.match((await text("alice", "cancel my reservation")).reply, /couldn't find/);

  const bobs = await book("bob", 1, TOMORROW, "10:00");
  const r = await text("alice", "cancel my reservation");
  assert.equal(r.pending, undefined);
  const forged = await say("alice", {
    action: { type: "select_reservation", reservationId: bobs.id },
    state: { intent: "cancel" },
  });
  assert.equal(forged.pending, undefined);
});

test("reschedule: proposes the new time, checks availability, keeps duration", async () => {
  const mine = await book("alice", 1, TOMORROW, "10:00", 60);
  let r = await text("alice", "Can I change my booking to 16:00?");
  assert.equal(r.pending?.kind, "reschedule");
  if (r.pending?.kind !== "reschedule") throw new Error();
  assert.equal(r.pending.params.start, `${TOMORROW}T16:00:00.000Z`); // same day, new time
  assert.equal(r.pending.params.durationMinutes, 60);
  assert.equal(r.pending.amount, 26);

  const done = await rescheduleReservationCore(db, "alice", r.pending.params, NOW);
  assert.equal(done.start, `${TOMORROW}T16:00:00.000Z`);

  await book("bob", 1, TOMORROW, "18:00");
  r = await text("alice", "reschedule to 18:00");
  assert.equal(r.pending, undefined);
  assert.match(r.reply, /already booked/);
});

test("reschedule: asks for the new time when none is given", async () => {
  await book("alice", 1, TOMORROW, "10:00");
  const r = await text("alice", "I want to reschedule my reservation");
  assert.match(r.reply, /new date and time/i);
  const r2 = await text("alice", "tomorrow at 17:00", r.state);
  assert.equal(r2.pending?.kind, "reschedule");
});

test("find: near-me asks for location, then lists real stations with distance", async () => {
  let r = await text("alice", "Find the nearest charging station");
  assert.equal(r.needsLocation, true);

  r = await say("alice", { text: "Find the nearest charging station", context: { tzOffsetMinutes: 0, lat: 36.8, lng: 10.18 } });
  const c = r.cards[0];
  if (c?.type !== "chargers") throw new Error();
  assert.equal(c.items[0].id, "ch1");
  assert.equal(c.items[0].distanceKm, 0);
});

test("info answers come from real data and real rules", async () => {
  assert.match((await text("alice", "What are the prices?")).reply, /0\.5 and 0\.5 TND\/kWh/);
  assert.match((await text("alice", "What connector types do you have?")).reply, /CCS, Type 2/);
  assert.match((await text("alice", "What power do the chargers have?")).reply, /22, 50 kW/);
  assert.match((await text("alice", "What are the reservation conditions?")).reply, /15 minutes and 8 hours/);
  assert.match((await text("alice", "What do the reservation statuses mean?")).reply, /confirmed.*cancelled.*completed.*expired/);
  await db.recursiveDelete(db.collection("ev_chargers"));
  assert.match((await text("alice", "What are the prices?")).reply, /don't have pricing data/);
});

test("tampered client state is ignored, and actions without context do nothing", async () => {
  const bad = { intent: "book", date: "../../x", time: "99:99", chargerId: "a/b", connectorId: "x", durationMinutes: -1 };
  const r = await text("alice", "hello", bad as unknown as ChatState);
  assert.match(r.reply, /Chargi AI Assistant/);
  const a = await say("alice", { action: { type: "select_connector", chargerId: "ch1", connectorId: 1 }, state: bad as unknown as ChatState });
  assert.equal(a.pending, undefined);
});

test("local time zone: 'tomorrow at 14:00' for a user in UTC+1 is 13:00 UTC", async () => {
  const r = await handleTurn({ db, nlu, now: () => NOW }, "alice", {
    text: "book a station tomorrow at 14:00 for 1 hour",
    context: { tzOffsetMinutes: 60 },
  });
  const picked = await handleTurn({ db, nlu, now: () => NOW }, "alice", {
    action: { type: "select_connector", chargerId: "ch1", connectorId: 1 },
    state: r.state,
    context: { tzOffsetMinutes: 60 },
  });
  if (picked.pending?.kind !== "create") throw new Error("expected create");
  const startUtc = new Date(picked.pending.params.start);
  assert.equal(startUtc.getUTCHours(), 13);
});

// ---- LLM quota (Firestore-backed counters) -----------------------------------

import { consumeLlmQuota } from "../src/chatbot/quota";

test("quota: per-minute cap, window reset, per-user isolation", async () => {
  await db.recursiveDelete(db.collection("chat_rate"));
  const limits = { perMinute: 3, perDay: 100 };
  const t0 = Date.UTC(2026, 5, 1, 10, 0, 5);

  assert.equal(await consumeLlmQuota(db, "alice", t0, limits), true);
  assert.equal(await consumeLlmQuota(db, "alice", t0 + 1000, limits), true);
  assert.equal(await consumeLlmQuota(db, "alice", t0 + 2000, limits), true);
  assert.equal(await consumeLlmQuota(db, "alice", t0 + 3000, limits), false); // 4th in the same minute
  assert.equal(await consumeLlmQuota(db, "bob", t0 + 3000, limits), true); // other user unaffected
  assert.equal(await consumeLlmQuota(db, "alice", t0 + 60_000, limits), true); // next minute
});

test("quota: per-day cap, and a refused call spends nothing", async () => {
  await db.recursiveDelete(db.collection("chat_rate"));
  const limits = { perMinute: 100, perDay: 2 };
  const day = Date.UTC(2026, 5, 1, 8, 0, 0);

  assert.equal(await consumeLlmQuota(db, "carol", day, limits), true);
  assert.equal(await consumeLlmQuota(db, "carol", day + 5 * 60_000, limits), true);
  assert.equal(await consumeLlmQuota(db, "carol", day + 10 * 60_000, limits), false);
  assert.equal(await consumeLlmQuota(db, "carol", day + 11 * 60_000, limits), false);
  assert.equal((await db.collection("chat_rate").doc("carol").get()).get("dayCount"), 2); // refusals not counted
  assert.equal(await consumeLlmQuota(db, "carol", day + 24 * 3600_000, limits), true); // next day
});

test("quota: concurrent calls never exceed the cap", async () => {
  await db.recursiveDelete(db.collection("chat_rate"));
  const limits = { perMinute: 5, perDay: 100 };
  const t = Date.UTC(2026, 5, 1, 12, 0, 0);
  const results = await Promise.all(Array.from({ length: 12 }, () => consumeLlmQuota(db, "dave", t, limits)));
  assert.equal(results.filter(Boolean).length, 5);
});
