/**
 * Integration tests against the Firestore emulator. Run with:
 *   npx firebase emulators:exec --only firestore --project demo-chargi \
 *     "npm run test:emulator"
 */
import { test, before, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";

import {
  cancelReservationCore,
  createReservationCore,
  rescheduleReservationCore,
  searchAvailableChargersCore,
} from "../src/reservations";

const HOUR = 60 * 60 * 1000;
let db: Firestore;

const NOW = new Date();
const at = (hoursFromNow: number): string =>
  new Date(NOW.getTime() + hoursFromNow * HOUR).toISOString();

before(() => {
  assert.ok(process.env["FIRESTORE_EMULATOR_HOST"], "run inside emulators:exec");
  initializeApp({ projectId: "demo-chargi" });
  db = getFirestore();
});

beforeEach(async () => {
  for (const name of ["reservations", "connector_locks", "notifications", "ev_chargers", "users"]) {
    await db.recursiveDelete(db.collection(name));
  }
  await db.collection("ev_chargers").doc("ch1").set({
    name: "Station One",
    isActive: true,
    latitude: 36.8,
    longitude: 10.18,
    pricePerKwh: 0.5,
    reservationFee: 1,
    connectors: [
      { connectorId: 1, type: "CCS", power: 50, status: "free" },
      { connectorId: 2, type: "Type 2", power: 22, status: "free" },
    ],
  });
  await db.collection("ev_chargers").doc("off").set({ name: "Off", isActive: false, connectors: [{ power: 7 }] });
});

const book = (uid: string | undefined, startH: number, minutes = 60, connectorId: unknown = 1, chargerId = "ch1") =>
  createReservationCore(db, uid, `${uid}@x.test`, { chargerId, connectorId, start: at(startH), durationMinutes: minutes }, NOW);

async function code(p: Promise<unknown>): Promise<string> {
  try {
    await p;
    return "ok";
  } catch (e) {
    return (e as { code: string }).code;
  }
}

test("creates a confirmed reservation, priced server-side, mirrored to the user", async () => {
  const r = await book("alice", 24, 60, 1);
  assert.equal(r.status, "confirmed");
  assert.equal(r.amount, 26); // 50kW * 1h * 0.5 + 1 fee
  assert.equal(r.stationName, "Station One");
  const top = await db.collection("reservations").doc(r.id).get();
  const mirror = await db.collection("users").doc("alice").collection("reservations").doc(r.id).get();
  assert.equal(top.get("userId"), "alice");
  assert.equal(top.get("status"), "confirmed");
  assert.equal(top.get("reservationStatus"), "confirmed");
  assert.equal(mirror.exists, true);
  assert.equal((await db.collection("notifications").get()).size, 1);
});

test("rejects unauthenticated, past, bad duration, unknown station/connector, inactive station", async () => {
  assert.equal(await code(book(undefined, 24)), "unauthenticated");
  assert.equal(await code(book("alice", -5)), "invalid-argument");
  assert.equal(await code(book("alice", 24, 5)), "invalid-argument");
  assert.equal(await code(book("alice", 24, 60, 1, "nope")), "not-found");
  assert.equal(await code(book("alice", 24, 60, 99)), "not-found");
  assert.equal(await code(book("alice", 24, 60, 1, "off")), "failed-precondition");
  assert.equal((await db.collection("reservations").get()).size, 0);
});

test("refuses an overlapping slot on the same connector, allows other connector and back-to-back", async () => {
  await book("alice", 24, 60, 1); // 24h..25h
  assert.equal(await code(book("bob", 24, 60, 1)), "already-exists"); // same
  assert.equal(await code(book("bob", 24.5, 60, 1)), "already-exists"); // partial
  assert.equal(await code(book("bob", 23.5, 60, 1)), "already-exists"); // partial before
  assert.equal(await code(book("bob", 24, 60, 2)), "ok"); // other connector
  assert.equal(await code(book("bob", 25, 60, 1)), "ok"); // back-to-back after
  assert.equal(await code(book("bob", 23, 60, 1)), "ok"); // back-to-back before
});

test("concurrent bookings of the same slot: exactly one wins", async () => {
  const results = await Promise.all(
    Array.from({ length: 8 }, (_, i) => code(book(`user${i}`, 48, 60, 1))),
  );
  assert.equal(results.filter((r) => r === "ok").length, 1, JSON.stringify(results));
  assert.equal(results.filter((r) => r === "already-exists").length, 7);
  const confirmed = await db.collection("reservations").where("status", "==", "confirmed").get();
  assert.equal(confirmed.size, 1);
});

test("cancel: owner only, frees the slot, cannot cancel twice", async () => {
  const r = await book("alice", 24, 60, 1);
  assert.equal(await code(cancelReservationCore(db, "mallory", r.id, NOW)), "not-found");
  assert.equal(await code(cancelReservationCore(db, undefined, r.id, NOW)), "unauthenticated");
  assert.equal(await code(cancelReservationCore(db, "alice", "missing", NOW)), "not-found");

  const c = await cancelReservationCore(db, "alice", r.id, NOW);
  assert.equal(c.status, "cancelled");
  assert.equal((await db.collection("reservations").doc(r.id).get()).get("status"), "cancelled");
  assert.equal(
    (await db.collection("users").doc("alice").collection("reservations").doc(r.id).get()).get("reservationStatus"),
    "cancelled",
  );
  assert.equal(await code(cancelReservationCore(db, "alice", r.id, NOW)), "failed-precondition");
  assert.equal(await code(book("bob", 24, 60, 1)), "ok"); // slot is free again
});

test("cannot cancel a reservation that already started", async () => {
  const r = await book("alice", 0.1, 60, 1); // starts in 6 minutes
  const later = new Date(NOW.getTime() + HOUR);
  assert.equal(await code(cancelReservationCore(db, "alice", r.id, later)), "failed-precondition");
});

test("reschedule: moves atomically, rejects conflicts, ignores itself, owner only", async () => {
  const a = await book("alice", 24, 60, 1); // 24-25
  await book("bob", 27, 60, 1); // 27-28
  const resched = (uid: string, id: string, startH: number, minutes?: number) =>
    rescheduleReservationCore(db, uid, { reservationId: id, start: at(startH), durationMinutes: minutes }, NOW);

  assert.equal(await code(resched("mallory", a.id, 30)), "not-found");
  assert.equal(await code(resched("alice", a.id, 27.5)), "already-exists"); // collides with bob
  assert.equal(await code(resched("alice", a.id, 24.5)), "ok"); // overlaps only itself
  const moved = await resched("alice", a.id, 30, 120);
  assert.equal(moved.durationMinutes, 120);
  assert.equal(moved.amount, 51); // 50kW * 2h * 0.5 + 1
  const mirror = await db.collection("users").doc("alice").collection("reservations").doc(a.id).get();
  assert.equal(mirror.get("durationMinutes"), 120);
  assert.equal(await code(book("carol", 24, 60, 1)), "ok"); // old slot freed
});

test("search: distance, window availability, hides inactive stations", async () => {
  await book("alice", 24, 60, 1);
  const free = await searchAvailableChargersCore(db, "bob", { lat: 36.8, lng: 10.18 }, NOW);
  assert.deepEqual(free.map((c) => c.id), ["ch1"]);
  assert.equal(free[0].distanceKm, 0);

  const busy = await searchAvailableChargersCore(db, "bob", { start: at(24.25), durationMinutes: 30 }, NOW);
  const conns = busy[0].connectors;
  assert.equal(conns.find((c) => c.connectorId === 1)?.available, false);
  assert.equal(conns.find((c) => c.connectorId === 2)?.available, true);
  assert.equal(busy[0].availableCount, 1);

  assert.equal(await code(searchAvailableChargersCore(db, undefined, {}, NOW)), "unauthenticated");
  const far = await searchAvailableChargersCore(db, "bob", { lat: 0, lng: 0, radiusKm: 10 }, NOW);
  assert.equal(far.length, 0);
});

// ---- Reservations created by the first app version (legacy format) ---------

import { listUserReservations } from "../src/reservations";
import { Timestamp } from "firebase-admin/firestore";

async function seedLegacy(id: string, uid: string, hoursFromNow: number, extra: Record<string, unknown> = {}) {
  const start = Timestamp.fromMillis(NOW.getTime() + hoursFromNow * HOUR);
  const data = {
    id, userId: uid, chargerId: "ch1", connectorId: 1, stationName: "Station One", connectorName: "CCS",
    startDateTime: start, durationMinutes: 60, amount: 26, currency: "TND",
    paymentStatus: "paid", reservationStatus: "confirmed", ...extra,
  };
  await db.collection("reservations").doc(id).set(data);
  await db.collection("users").doc(uid).collection("reservations").doc(id).set(data);
}

test("legacy: shown in the user's list with a readable status", async () => {
  await seedLegacy("old1", "alice", 30);
  const list = await listUserReservations(db, "alice");
  assert.equal(list.length, 1);
  assert.equal(list[0].status, "confirmed");
  assert.equal(list[0].connectorId, 1);
  assert.equal(Date.parse(list[0].end) - Date.parse(list[0].start), 60 * 60000);
});

test("legacy: can be cancelled (both copies), instead of crashing", async () => {
  await seedLegacy("old2", "alice", 30);
  const r = await cancelReservationCore(db, "alice", "old2", NOW);
  assert.equal(r.status, "cancelled");
  assert.equal((await db.collection("reservations").doc("old2").get()).get("reservationStatus"), "cancelled");
  assert.equal((await db.collection("users").doc("alice").collection("reservations").doc("old2").get()).get("status"), "cancelled");
});

test("legacy: cancelling works even when the user's copy is missing", async () => {
  await seedLegacy("old3", "alice", 30);
  await db.collection("users").doc("alice").collection("reservations").doc("old3").delete();
  assert.equal(await code(cancelReservationCore(db, "alice", "old3", NOW)), "ok");
});

test("legacy: rescheduling upgrades the document and then blocks the new slot", async () => {
  await seedLegacy("old4", "alice", 30);
  const start = new Date(NOW.getTime() + 50 * HOUR).toISOString();
  const r = await rescheduleReservationCore(db, "alice", { reservationId: "old4", start }, NOW);
  assert.equal(r.start, start);
  const doc = await db.collection("reservations").doc("old4").get();
  assert.equal(doc.get("status"), "confirmed");
  assert.equal(doc.get("connectorKey"), "1");
  assert.ok(doc.get("end") instanceof Timestamp);
  // it now takes part in overlap checks
  assert.equal(await code(book("bob", 50, 60, 1)), "already-exists"); // same slot, connector 1
});

test("legacy: unusable documents give a clear error, not an internal crash", async () => {
  await db.collection("reservations").doc("bad1").set({ userId: "alice", chargerId: "ch1", reservationStatus: "confirmed" });
  assert.equal(await code(cancelReservationCore(db, "alice", "bad1", NOW)), "failed-precondition");

  await seedLegacy("noconn", "alice", 30, { connectorId: null });
  const start = new Date(NOW.getTime() + 50 * HOUR).toISOString();
  assert.equal(await code(rescheduleReservationCore(db, "alice", { reservationId: "noconn", start }, NOW)), "failed-precondition");
  // and the list simply skips the broken one
  const ids = (await listUserReservations(db, "alice")).map((r) => r.id);
  assert.ok(!ids.includes("bad1"));
});
