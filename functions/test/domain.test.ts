import { test } from "node:test";
import assert from "node:assert/strict";

import {
  checkModifiable,
  computePrice,
  effectiveConnectorId,
  haversineKm,
  overlaps,
  resolveConnector,
  validateWindow,
} from "../src/domain";

const MIN = 60 * 1000;
const NOW = Date.UTC(2026, 5, 1, 12, 0, 0);

test("overlaps: half-open intervals", () => {
  assert.equal(overlaps(0, 60, 30, 90), true);
  assert.equal(overlaps(0, 60, 60, 120), false); // back to back
  assert.equal(overlaps(60, 120, 0, 60), false);
  assert.equal(overlaps(0, 120, 30, 60), true); // contained
  assert.equal(overlaps(30, 60, 0, 120), true);
  assert.equal(overlaps(0, 10, 20, 30), false);
});

test("effectiveConnectorId: explicit id, then 1-based index", () => {
  assert.equal(effectiveConnectorId({ connectorId: 7 }, 0), 7);
  assert.equal(effectiveConnectorId({ id: "3" }, 0), 3);
  assert.equal(effectiveConnectorId({ connector_id: 2 }, 5), 2);
  assert.equal(effectiveConnectorId({}, 0), 1);
  assert.equal(effectiveConnectorId({}, 3), 4);
});

test("resolveConnector: matches or returns null, never guesses", () => {
  const connectors = [{ connectorId: 10 }, {}, { id: 3 }];
  assert.equal(resolveConnector(connectors, 10)?.index, 0);
  assert.equal(resolveConnector(connectors, "10")?.key, "10");
  assert.equal(resolveConnector(connectors, 2)?.index, 1); // positional id
  assert.equal(resolveConnector(connectors, 3)?.index, 2);
  assert.equal(resolveConnector(connectors, 99), null);
  assert.equal(resolveConnector(connectors, "abc"), null);
  assert.equal(resolveConnector(undefined, 1), null);
});

test("computePrice: power x hours x price + fee, with fallbacks", () => {
  const charger = { pricePerKwh: 0.5, reservationFee: 1, maxPower: 22 };
  assert.deepEqual(computePrice(charger, { power: 50 }, 60), {
    energy: 25,
    fee: 1,
    total: 26,
  });
  // falls back to the station's maxPower, price_per_kwh alias
  assert.equal(computePrice({ price_per_kwh: "2", maxPower: 10 }, {}, 30).total, 10);
  assert.equal(computePrice({}, {}, 60).total, 0);
});

test("validateWindow", () => {
  assert.equal(validateWindow(NOW + 10 * MIN, 60, NOW), null);
  assert.equal(validateWindow(NOW - 10 * MIN, 60, NOW), null); // tolerance
  assert.equal(validateWindow(NOW - 20 * MIN, 60, NOW), "start_in_past");
  assert.equal(validateWindow(NOW + 91 * 24 * 60 * MIN, 60, NOW), "start_too_far");
  assert.equal(validateWindow(NOW, 5, NOW), "invalid_duration");
  assert.equal(validateWindow(NOW, 481, NOW), "invalid_duration");
  assert.equal(validateWindow(NOW, 30.5, NOW), "invalid_duration");
  assert.equal(validateWindow(NOW, NaN, NOW), "invalid_duration");
});

test("checkModifiable: only confirmed, not-yet-started reservations", () => {
  assert.equal(checkModifiable("confirmed", NOW + MIN, NOW), null);
  assert.equal(checkModifiable("cancelled", NOW + MIN, NOW), "not_confirmed");
  assert.equal(checkModifiable("completed", NOW + MIN, NOW), "not_confirmed");
  assert.equal(checkModifiable("confirmed", NOW - MIN, NOW), "already_started");
});

test("haversineKm", () => {
  assert.ok(Math.abs(haversineKm(36.8, 10.18, 36.8, 10.18)) < 1e-9);
  const d = haversineKm(36.8065, 10.1815, 35.8256, 10.6084); // Tunis - Sousse
  assert.ok(d > 110 && d < 120, `unexpected distance ${d}`);
});

import { normalizeReservation } from "../src/domain";

const ts = (ms: number) => ({ toMillis: () => ms });

test("normalizeReservation: current format", () => {
  const n = normalizeReservation({
    start: ts(1000), end: ts(1000 + 60 * 60000), durationMinutes: 60,
    status: "confirmed", connectorKey: "2",
  });
  assert.deepEqual(n, { startMs: 1000, endMs: 3601000, durationMinutes: 60, status: "confirmed", connectorKey: "2" });
});

test("normalizeReservation: legacy format (startDateTime, reservationStatus, connectorId)", () => {
  const n = normalizeReservation({
    startDateTime: ts(5000), durationMinutes: 30, reservationStatus: "confirmed", connectorId: 3,
  });
  assert.deepEqual(n, { startMs: 5000, endMs: 5000 + 30 * 60000, durationMinutes: 30, status: "confirmed", connectorKey: "3" });
});

test("normalizeReservation: derives duration from end, tolerates a missing connector, rejects unusable documents", () => {
  const a = normalizeReservation({ start: ts(0), end: ts(45 * 60000), status: "cancelled" });
  assert.equal(a?.durationMinutes, 45);
  assert.equal(a?.connectorKey, null);
  assert.equal(normalizeReservation({ durationMinutes: 60 }), null); // no start
  assert.equal(normalizeReservation({ startDateTime: ts(1) }), null); // no end, no duration
  assert.equal(normalizeReservation({ start: "2026-01-01", durationMinutes: 60 }), null); // not a timestamp
  assert.equal(normalizeReservation({ start: ts(0), durationMinutes: 60 })?.status, "unknown");
});
