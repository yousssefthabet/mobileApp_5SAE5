import { Firestore, Timestamp, FieldValue, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  checkModifiable,
  computePrice,
  effectiveConnectorId,
  haversineKm,
  normalizeReservation,
  NormalizedReservation,
  numberOf,
  overlaps,
  resolveConnector,
  validateWindow,
  Connector,
} from "./domain";

/** Result returned to the app. Dates are ISO-8601 strings (UTC). */
export interface ReservationResult {
  id: string;
  chargerId: string;
  connectorId: number;
  stationName: string;
  connectorName: string;
  start: string;
  end: string;
  durationMinutes: number;
  amount: number;
  currency: string;
  status: string;
}

const MINUTE_MS = 60 * 1000;
const WINDOW_MESSAGES = {
  invalid_duration: "Duration must be between 15 minutes and 8 hours.",
  start_in_past: "This reservation time has already passed.",
  start_too_far: "Reservations can be made up to 90 days in advance.",
} as const;

function requireUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Please sign in to continue.");
  }
  return uid;
}

function parseStart(value: unknown): number {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "A start time is required.");
  }
  const ms = Date.parse(value);
  if (Number.isNaN(ms)) {
    throw new HttpsError("invalid-argument", "The start time is not valid.");
  }
  return ms;
}

function parseId(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim() === "" || value.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return value.trim();
}

function assertWindow(startMs: number, minutes: number, nowMs: number): void {
  const err = validateWindow(startMs, minutes, nowMs);
  if (err) throw new HttpsError("invalid-argument", WINDOW_MESSAGES[err], { code: err });
}

/** Normalised view of a stored reservation, or a clear error for unusable documents. */
function normalizeOrThrow(d: Record<string, unknown>): NormalizedReservation {
  const n = normalizeReservation(d);
  if (!n) {
    throw new HttpsError(
      "failed-precondition",
      "This reservation is missing data and cannot be changed from the app.",
      { code: "unreadable_reservation" },
    );
  }
  return n;
}

/** Works for current and legacy documents (see normalizeReservation). */
export function toResult(id: string, d: Record<string, unknown>): ReservationResult {
  const n = normalizeOrThrow(d);
  return {
    id,
    chargerId: String(d["chargerId"]),
    connectorId: Number(d["connectorId"]),
    stationName: String(d["stationName"] ?? ""),
    connectorName: String(d["connectorName"] ?? ""),
    start: new Date(n.startMs).toISOString(),
    end: new Date(n.endMs).toISOString(),
    durationMinutes: n.durationMinutes,
    amount: Number(d["amount"]),
    currency: String(d["currency"] ?? "TND"),
    status: n.status,
  };
}

function connectorLabel(c: Connector, fallbackId: string): string {
  const name = c["name"] ?? c["type"];
  return typeof name === "string" && name.trim() !== "" ? name : `Connector ${fallbackId}`;
}

/**
 * Reads confirmed reservations on a connector that end after [startMs], and
 * returns those that actually overlap the requested window. Must be called
 * with a transaction so concurrent bookings are serialised.
 */
async function findConflicts(
  db: Firestore,
  tx: Transaction,
  chargerId: string,
  connectorKey: string,
  startMs: number,
  endMs: number,
  excludeId?: string,
): Promise<string[]> {
  const snap = await tx.get(
    db
      .collection("reservations")
      .where("chargerId", "==", chargerId)
      .where("connectorKey", "==", connectorKey)
      .where("status", "==", "confirmed")
      .where("end", ">", Timestamp.fromMillis(startMs)),
  );
  return snap.docs
    .filter((doc) => doc.id !== excludeId)
    .filter((doc) => {
      const s = (doc.get("start") as Timestamp).toMillis();
      const e = (doc.get("end") as Timestamp).toMillis();
      return overlaps(startMs, endMs, s, e);
    })
    .map((doc) => doc.id);
}

function lockRef(db: Firestore, chargerId: string, connectorKey: string) {
  return db.collection("connector_locks").doc(`${chargerId}_${connectorKey}`);
}

function notify(
  db: Firestore,
  tx: Transaction,
  userId: string,
  type: string,
  title: string,
  body: string,
  reservationId: string,
): void {
  tx.set(db.collection("notifications").doc(), {
    userId,
    type,
    title,
    body,
    reservationId,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

export interface CreateInput {
  chargerId: unknown;
  connectorId: unknown;
  start: unknown;
  durationMinutes: unknown;
}

export async function createReservationCore(
  db: Firestore,
  uid: string | undefined,
  email: string | undefined,
  input: CreateInput,
  now: Date = new Date(),
): Promise<ReservationResult> {
  const userId = requireUid(uid);
  const chargerId = parseId(input.chargerId, "chargerId");
  const startMs = parseStart(input.start);
  const minutes = numberOf(input.durationMinutes, NaN);
  assertWindow(startMs, minutes, now.getTime());
  const endMs = startMs + minutes * MINUTE_MS;

  const reservationRef = db.collection("reservations").doc();
  const mirrorRef = db.collection("users").doc(userId).collection("reservations").doc(reservationRef.id);

  return db.runTransaction(async (tx) => {
    const chargerSnap = await tx.get(db.collection("ev_chargers").doc(chargerId));
    if (!chargerSnap.exists) throw new HttpsError("not-found", "Charging station not found.");
    const charger = chargerSnap.data() as Record<string, unknown>;
    if (charger["isActive"] === false) {
      throw new HttpsError("failed-precondition", "This charging station is currently inactive.");
    }

    const resolved = resolveConnector(charger["connectors"], input.connectorId);
    if (!resolved) throw new HttpsError("not-found", "Connector not found on this station.");

    const lock = lockRef(db, chargerId, resolved.key);
    await tx.get(lock);

    const conflicts = await findConflicts(db, tx, chargerId, resolved.key, startMs, endMs);
    if (conflicts.length > 0) {
      throw new HttpsError("already-exists", "This time slot is no longer available.", {
        code: "slot_unavailable",
      });
    }

    const price = computePrice(charger, resolved.connector, minutes);
    const stationName = String(charger["name"] ?? charger["stationName"] ?? "Charging station");
    const connectorName = connectorLabel(resolved.connector, resolved.key);
    const connectorId = Number(resolved.key);

    const data = {
      id: reservationRef.id,
      userId,
      userEmail: email ?? null,
      chargerId,
      connectorId,
      connectorKey: resolved.key,
      stationName,
      connectorName,
      start: Timestamp.fromMillis(startMs),
      end: Timestamp.fromMillis(endMs),
      durationMinutes: minutes,
      amount: price.total,
      currency: "TND",
      status: "confirmed",
      // Legacy fields still read by existing screens.
      startDateTime: Timestamp.fromMillis(startMs),
      reservationStatus: "confirmed",
      // Payments are simulated in the app: nothing is actually charged.
      paymentMethod: "demo",
      paymentStatus: "demo",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    tx.set(reservationRef, data);
    tx.set(mirrorRef, data);
    // Bumping the lock document makes concurrent bookings of the same
    // connector conflict, on top of the serialisable query read above.
    tx.set(
      lock,
      {
        chargerId,
        connectorKey: resolved.key,
        rev: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    notify(db, tx, userId, "reservation_confirmed", "Reservation confirmed",
      `${stationName} - ${connectorName}`, reservationRef.id);

    return toResult(reservationRef.id, {
      ...data,
      start: Timestamp.fromMillis(startMs),
      end: Timestamp.fromMillis(endMs),
    });
  });
}

// ---------------------------------------------------------------------------
// Cancel
// ---------------------------------------------------------------------------

async function loadOwned(
  db: Firestore,
  tx: Transaction,
  userId: string,
  id: string,
) {
  const snap = await tx.get(db.collection("reservations").doc(id));
  // Same answer for "missing" and "someone else's": never reveal other users' data.
  if (!snap.exists || snap.get("userId") !== userId) {
    throw new HttpsError("not-found", "Reservation not found.");
  }
  return snap;
}

function assertModifiable(status: unknown, startMs: number, nowMs: number): void {
  const err = checkModifiable(status, startMs, nowMs);
  if (err === "not_confirmed") {
    throw new HttpsError("failed-precondition", "Only confirmed reservations can be changed.", { code: err });
  }
  if (err === "already_started") {
    throw new HttpsError("failed-precondition", "This reservation has already started.", { code: err });
  }
}

export async function cancelReservationCore(
  db: Firestore,
  uid: string | undefined,
  reservationId: unknown,
  now: Date = new Date(),
): Promise<ReservationResult> {
  const userId = requireUid(uid);
  const id = parseId(reservationId, "reservationId");

  return db.runTransaction(async (tx) => {
    const snap = await loadOwned(db, tx, userId, id);
    const d = snap.data() as Record<string, unknown>;
    const n = normalizeOrThrow(d);
    assertModifiable(n.status, n.startMs, now.getTime());

    const mirrorRef = db.collection("users").doc(userId).collection("reservations").doc(id);
    const mirrorSnap = await tx.get(mirrorRef); // all reads happen before any write

    const patch = {
      status: "cancelled",
      reservationStatus: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.update(snap.ref, patch);
    if (mirrorSnap.exists) tx.update(mirrorRef, patch);
    notify(db, tx, userId, "reservation_cancelled", "Reservation cancelled",
      String(d["stationName"] ?? ""), id);

    return toResult(id, { ...d, status: "cancelled" });
  });
}

// ---------------------------------------------------------------------------
// Reschedule
// ---------------------------------------------------------------------------

export interface RescheduleInput {
  reservationId: unknown;
  start: unknown;
  durationMinutes?: unknown;
}

export async function rescheduleReservationCore(
  db: Firestore,
  uid: string | undefined,
  input: RescheduleInput,
  now: Date = new Date(),
): Promise<ReservationResult> {
  const userId = requireUid(uid);
  const id = parseId(input.reservationId, "reservationId");
  const newStartMs = parseStart(input.start);

  return db.runTransaction(async (tx) => {
    const snap = await loadOwned(db, tx, userId, id);
    const d = snap.data() as Record<string, unknown>;
    const n = normalizeOrThrow(d);
    assertModifiable(n.status, n.startMs, now.getTime());

    const minutes =
      input.durationMinutes === undefined || input.durationMinutes === null
        ? n.durationMinutes
        : numberOf(input.durationMinutes, NaN);
    assertWindow(newStartMs, minutes, now.getTime());
    const newEndMs = newStartMs + minutes * MINUTE_MS;

    const chargerId = String(d["chargerId"]);
    const connectorKey = n.connectorKey;
    if (connectorKey === null) {
      throw new HttpsError(
        "failed-precondition",
        "This reservation does not say which connector it uses and cannot be rescheduled.",
        { code: "unreadable_reservation" },
      );
    }
    const mirrorRef = db.collection("users").doc(userId).collection("reservations").doc(id);
    const mirrorSnap = await tx.get(mirrorRef);
    const chargerSnap = await tx.get(db.collection("ev_chargers").doc(chargerId));
    if (!chargerSnap.exists || chargerSnap.get("isActive") === false) {
      throw new HttpsError("failed-precondition", "This charging station is no longer available.");
    }
    const charger = chargerSnap.data() as Record<string, unknown>;
    const resolved = resolveConnector(charger["connectors"], connectorKey);
    if (!resolved) throw new HttpsError("not-found", "Connector not found on this station.");

    const lock = lockRef(db, chargerId, connectorKey);
    await tx.get(lock);

    const conflicts = await findConflicts(db, tx, chargerId, connectorKey, newStartMs, newEndMs, id);
    if (conflicts.length > 0) {
      throw new HttpsError("already-exists", "This time slot is no longer available.", {
        code: "slot_unavailable",
      });
    }

    const price = computePrice(charger, resolved.connector, minutes);
    const patch = {
      start: Timestamp.fromMillis(newStartMs),
      end: Timestamp.fromMillis(newEndMs),
      startDateTime: Timestamp.fromMillis(newStartMs),
      durationMinutes: minutes,
      amount: price.total,
      // Also upgrades a legacy document to the current format, so from now on
      // it takes part in overlap checks.
      status: n.status,
      reservationStatus: n.status,
      connectorKey,
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.update(snap.ref, patch);
    if (mirrorSnap.exists) tx.update(mirrorRef, patch);
    tx.set(lock, { rev: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    notify(db, tx, userId, "reservation_rescheduled", "Reservation updated",
      String(d["stationName"] ?? ""), id);

    return toResult(id, { ...d, ...patch, start: patch.start, end: patch.end });
  });
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

export interface SearchInput {
  lat?: unknown;
  lng?: unknown;
  start?: unknown;
  durationMinutes?: unknown;
  radiusKm?: unknown;
  limit?: unknown;
}

export interface ChargerSearchResult {
  id: string;
  name: string;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  distanceKm: number | null;
  pricePerKwh: number;
  connectors: {
    connectorId: number;
    type: string | null;
    powerKw: number;
    available: boolean;
  }[];
  availableCount: number;
}

export async function searchAvailableChargersCore(
  db: Firestore,
  uid: string | undefined,
  input: SearchInput,
  now: Date = new Date(),
): Promise<ChargerSearchResult[]> {
  requireUid(uid);

  const hasPosition = input.lat !== undefined && input.lng !== undefined;
  const lat = numberOf(input.lat, NaN);
  const lng = numberOf(input.lng, NaN);
  if (hasPosition && (!Number.isFinite(lat) || !Number.isFinite(lng))) {
    throw new HttpsError("invalid-argument", "The position is not valid.");
  }

  let startMs: number | null = null;
  let minutes = 60;
  if (input.start !== undefined && input.start !== null) {
    startMs = parseStart(input.start);
    minutes = input.durationMinutes === undefined ? 60 : numberOf(input.durationMinutes, NaN);
    assertWindow(startMs, minutes, now.getTime());
  }
  const endMs = startMs === null ? 0 : startMs + minutes * MINUTE_MS;
  const radiusKm = numberOf(input.radiusKm, Infinity);
  const limit = Math.min(Math.max(Math.trunc(numberOf(input.limit, 10)), 1), 25);

  const chargers = await db.collection("ev_chargers").where("isActive", "==", true).get();
  const results: ChargerSearchResult[] = [];

  for (const doc of chargers.docs) {
    const c = doc.data();
    const cLat = numberOf(c["latitude"], NaN);
    const cLng = numberOf(c["longitude"], NaN);
    const hasCoords = Number.isFinite(cLat) && Number.isFinite(cLng);
    const distanceKm =
      hasPosition && hasCoords ? Math.round(haversineKm(lat, lng, cLat, cLng) * 100) / 100 : null;
    if (distanceKm !== null && distanceKm > radiusKm) continue;

    const busyKeys = new Set<string>();
    if (startMs !== null) {
      const res = await db
        .collection("reservations")
        .where("chargerId", "==", doc.id)
        .where("status", "==", "confirmed")
        .where("end", ">", Timestamp.fromMillis(startMs))
        .get();
      for (const r of res.docs) {
        const s = (r.get("start") as Timestamp).toMillis();
        const e = (r.get("end") as Timestamp).toMillis();
        if (overlaps(startMs, endMs, s, e)) busyKeys.add(String(r.get("connectorKey")));
      }
    }

    const raw = Array.isArray(c["connectors"]) ? (c["connectors"] as Connector[]) : [];
    const connectors = raw.map((conn, i) => {
      const id = effectiveConnectorId(conn, i);
      const physicallyFree = String(conn["status"] ?? "free").toLowerCase() === "free";
      return {
        connectorId: id,
        type: typeof conn["type"] === "string" ? (conn["type"] as string) : null,
        powerKw: numberOf(conn["power"], numberOf(c["maxPower"])),
        available: physicallyFree && !busyKeys.has(String(id)),
      };
    });

    const availableCount = connectors.filter((x) => x.available).length;
    if (availableCount === 0) continue;

    results.push({
      id: doc.id,
      name: String(c["name"] ?? c["stationName"] ?? "Charging station"),
      address: typeof c["address"] === "string" ? (c["address"] as string) : null,
      latitude: hasCoords ? cLat : null,
      longitude: hasCoords ? cLng : null,
      distanceKm,
      pricePerKwh: numberOf(c["pricePerKwh"] ?? c["price_per_kwh"] ?? c["price"]),
      connectors,
      availableCount,
    });
  }

  results.sort((a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity));
  return results.slice(0, limit);
}

// ---------------------------------------------------------------------------
// Read-only helpers (used by the chat assistant for proposals; the booking
// transaction above remains the single source of truth).
// ---------------------------------------------------------------------------

/** Non-transactional check, used only to avoid proposing a taken slot. */
export async function isConnectorFree(
  db: Firestore,
  chargerId: string,
  connectorKey: string,
  startMs: number,
  endMs: number,
  excludeId?: string,
): Promise<boolean> {
  const snap = await db
    .collection("reservations")
    .where("chargerId", "==", chargerId)
    .where("connectorKey", "==", connectorKey)
    .where("status", "==", "confirmed")
    .where("end", ">", Timestamp.fromMillis(startMs))
    .get();
  return !snap.docs.some((doc) => {
    if (doc.id === excludeId) return false;
    const s = (doc.get("start") as Timestamp).toMillis();
    const e = (doc.get("end") as Timestamp).toMillis();
    return overlaps(startMs, endMs, s, e);
  });
}

/** The signed-in user's reservations, soonest first. Never reads other users'. */
export async function listUserReservations(
  db: Firestore,
  userId: string,
): Promise<ReservationResult[]> {
  const snap = await db.collection("reservations").where("userId", "==", userId).get();
  return snap.docs
    // Includes legacy documents; skips only those too incomplete to read.
    .filter((d) => normalizeReservation(d.data()) !== null)
    .map((d) => toResult(d.id, d.data()))
    .sort((a, b) => a.start.localeCompare(b.start));
}
