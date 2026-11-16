/**
 * Pure business rules for reservations. No Firebase imports, so everything
 * here is unit-testable without an emulator.
 */

export type Connector = Record<string, unknown>;

export const MIN_DURATION_MINUTES = 15;
export const MAX_DURATION_MINUTES = 480;
/** Same tolerance the app already applied when picking a start time. */
export const START_TOLERANCE_MS = 15 * 60 * 1000;
export const MAX_ADVANCE_DAYS = 90;

export function numberOf(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (value.trim() !== "" && Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

/**
 * Identifier of a connector, mirroring the app: explicit connectorId / id /
 * connector_id when present, otherwise its 1-based position.
 */
export function effectiveConnectorId(c: Connector, index: number): number {
  const raw = c["connectorId"] ?? c["id"] ?? c["connector_id"];
  const parsed = numberOf(raw, NaN);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : index + 1;
}

export interface ResolvedConnector {
  index: number;
  /** Canonical id, also used as the `connectorKey` stored on reservations. */
  key: string;
  connector: Connector;
}

/** Finds the connector matching [requested]; never falls back to "any free". */
export function resolveConnector(
  connectors: unknown,
  requested: unknown,
): ResolvedConnector | null {
  if (!Array.isArray(connectors)) return null;
  const wanted = numberOf(requested, NaN);
  if (!Number.isFinite(wanted)) return null;
  for (let i = 0; i < connectors.length; i++) {
    const c = connectors[i];
    if (c === null || typeof c !== "object") continue;
    const id = effectiveConnectorId(c as Connector, i);
    if (id === Math.trunc(wanted)) {
      return { index: i, key: String(id), connector: c as Connector };
    }
  }
  return null;
}

export interface Price {
  energy: number;
  fee: number;
  total: number;
}

const round2 = (n: number): number => Math.round(n * 100) / 100;

/** Same formula as the reservation screen, computed server-side. */
export function computePrice(
  charger: Record<string, unknown>,
  connector: Connector,
  durationMinutes: number,
): Price {
  const pricePerKwh = numberOf(
    charger["pricePerKwh"] ?? charger["price_per_kwh"] ?? charger["price"],
  );
  const fee = numberOf(charger["reservationFee"] ?? charger["reservation_fee"]);
  const powerKw = numberOf(connector["power"], numberOf(charger["maxPower"]));
  const energy = powerKw * (durationMinutes / 60) * pricePerKwh;
  return { energy: round2(energy), fee: round2(fee), total: round2(energy + fee) };
}

/** Half-open intervals: back-to-back reservations do not overlap. */
export function overlaps(
  aStart: number,
  aEnd: number,
  bStart: number,
  bEnd: number,
): boolean {
  return aStart < bEnd && bStart < aEnd;
}

export type WindowError =
  | "invalid_duration"
  | "start_in_past"
  | "start_too_far";

export function validateWindow(
  startMs: number,
  durationMinutes: number,
  nowMs: number,
): WindowError | null {
  if (
    !Number.isInteger(durationMinutes) ||
    durationMinutes < MIN_DURATION_MINUTES ||
    durationMinutes > MAX_DURATION_MINUTES
  ) {
    return "invalid_duration";
  }
  if (startMs < nowMs - START_TOLERANCE_MS) return "start_in_past";
  if (startMs > nowMs + MAX_ADVANCE_DAYS * 24 * 60 * 60 * 1000) {
    return "start_too_far";
  }
  return null;
}

export type ModifyError = "not_confirmed" | "already_started";

/** Cancelling and rescheduling share the same rule. */
export function checkModifiable(
  status: unknown,
  startMs: number,
  nowMs: number,
): ModifyError | null {
  if (status !== "confirmed") return "not_confirmed";
  if (startMs <= nowMs) return "already_started";
  return null;
}

export function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const rad = (d: number): number => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---------------------------------------------------------------------------
// Reading reservations written by older app versions
// ---------------------------------------------------------------------------

/** Anything with toMillis(), i.e. a Firestore Timestamp (kept duck-typed so this file stays Firebase-free). */
export interface MillisLike {
  toMillis(): number;
}

const isMillis = (v: unknown): v is MillisLike =>
  typeof v === "object" && v !== null && typeof (v as MillisLike).toMillis === "function";

export interface NormalizedReservation {
  startMs: number;
  endMs: number;
  durationMinutes: number;
  status: string;
  /** null when the document does not say which connector (cannot be rescheduled). */
  connectorKey: string | null;
}

/**
 * Reads a reservation document in either format:
 *  - current: start, end, status, connectorKey
 *  - legacy (created by the first app version): startDateTime, durationMinutes,
 *    reservationStatus, connectorId
 * Returns null when the essentials (start and end) cannot be determined.
 */
export function normalizeReservation(d: Record<string, unknown>): NormalizedReservation | null {
  const startMs = isMillis(d["start"])
    ? d["start"].toMillis()
    : isMillis(d["startDateTime"])
      ? d["startDateTime"].toMillis()
      : null;
  if (startMs === null) return null;

  let durationMinutes = numberOf(d["durationMinutes"], NaN);
  let endMs: number | null = null;
  if (isMillis(d["end"])) {
    endMs = d["end"].toMillis();
    if (!Number.isFinite(durationMinutes)) durationMinutes = Math.round((endMs - startMs) / 60000);
  } else if (Number.isFinite(durationMinutes)) {
    endMs = startMs + durationMinutes * 60000;
  }
  if (endMs === null || !Number.isFinite(durationMinutes)) return null;

  const status =
    typeof d["status"] === "string"
      ? d["status"]
      : typeof d["reservationStatus"] === "string"
        ? d["reservationStatus"]
        : "unknown";

  let connectorKey: string | null = null;
  if (typeof d["connectorKey"] === "string" && d["connectorKey"] !== "") {
    connectorKey = d["connectorKey"];
  } else {
    const id = numberOf(d["connectorId"], NaN);
    if (Number.isFinite(id)) connectorKey = String(Math.trunc(id));
  }

  return { startMs, endMs, durationMinutes, status, connectorKey };
}

// ---------------------------------------------------------------------------
// Loyalty points and the PROMO30 code (same rules as lib/services/reward_service.dart)
// ---------------------------------------------------------------------------

export const POINTS_PER_RESERVATION = 10;
export const PROMO_THRESHOLD_POINTS = 100;
export const PROMO_DISCOUNT_PERCENT = 30;
export const PROMO_CODE = "PROMO30";

/**
 * Current points of a user, derived ONLY from their reservations (which only
 * the server can write), so the balance cannot be forged from the app:
 *  - cancelled reservations give nothing;
 *  - a reservation that used the promo resets the counter to 0 (single use);
 *  - every other reservation gives `rewardPointsEarned` (default 10).
 * Reservations are processed in creation order.
 */
export function calculateRewardPoints(reservations: Record<string, unknown>[]): number {
  const createdOf = (r: Record<string, unknown>): number | null =>
    isMillis(r["createdAt"]) ? r["createdAt"].toMillis() : null;

  const sorted = [...reservations].sort((a, b) => {
    const ta = createdOf(a);
    const tb = createdOf(b);
    if (ta === null && tb === null) return 0;
    if (ta === null) return -1;
    if (tb === null) return 1;
    return ta - tb;
  });

  let points = 0;
  for (const r of sorted) {
    const raw = r["reservationStatus"] ?? r["status"];
    const status = typeof raw === "string" ? raw.toLowerCase() : "";
    if (status === "cancelled" || status === "annulée") continue;

    const discount = r["discountAmount"];
    const promo = r["promoCode"];
    const usedPromo =
      (typeof discount === "number" && discount > 0) ||
      (promo !== null && promo !== undefined && String(promo).trim() !== "");

    if (usedPromo) {
      points = 0;
    } else {
      const earned = r["rewardPointsEarned"];
      points += typeof earned === "number" ? Math.trunc(earned) : POINTS_PER_RESERVATION;
    }
  }
  return Math.max(points, 0);
}

/** Price after a percentage discount, rounded to 2 decimals. */
export function applyDiscount(total: number, percent: number): number {
  return Math.round(total * (1 - percent / 100) * 100) / 100;
}
