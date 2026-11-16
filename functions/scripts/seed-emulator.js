/**
 * Seeds the LOCAL Firestore emulator with a few charging stations and kiosks.
 * Refuses to run unless FIRESTORE_EMULATOR_HOST is set, so it can never write
 * to the real project.
 *
 *   FIRESTORE_EMULATOR_HOST=localhost:8185 node scripts/seed-emulator.js
 */
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("FIRESTORE_EMULATOR_HOST is not set: refusing to seed (would hit a real project).");
  process.exit(1);
}

initializeApp({ projectId: "chargi-b044b" });
const db = getFirestore();

const chargers = [
  {
    id: "tunis-centre", name: "Chargi Tunis Centre", address: "Avenue Habib Bourguiba, Tunis",
    latitude: 36.8008, longitude: 10.1815, isActive: true, pricePerKwh: 0.65, reservationFee: 1,
    maxPower: 50, openingHoursText: "24/7",
    connectors: [
      { connectorId: 1, type: "CCS", power: 50, status: "free" },
      { connectorId: 2, type: "Type 2", power: 22, status: "free" },
    ],
  },
  {
    id: "lac-1", name: "Chargi Lac 1", address: "Les Berges du Lac, Tunis",
    latitude: 36.8326, longitude: 10.2293, isActive: true, pricePerKwh: 0.7, reservationFee: 1,
    maxPower: 22, openingHoursText: "06:00 - 23:00",
    connectors: [
      { connectorId: 1, type: "Type 2", power: 22, status: "free" },
      { connectorId: 2, type: "Type 2", power: 22, status: "free" },
      { connectorId: 3, type: "CHAdeMO", power: 50, status: "free" },
    ],
  },
  {
    id: "ariana", name: "Chargi Ariana", address: "Ariana Centre",
    latitude: 36.8625, longitude: 10.1956, isActive: true, pricePerKwh: 0.6, reservationFee: 0.5,
    maxPower: 22, openingHoursText: "24/7",
    connectors: [{ connectorId: 1, type: "Type 2", power: 22, status: "free" }],
  },
];

const kiosks = [
  { id: "kiosk-tunis", name: "Kiosque Tunis Centre", address: "Place de la Victoire, Tunis", latitude: 36.7992, longitude: 10.1701, openingHoursText: "08:00 - 20:00" },
  { id: "kiosk-lac", name: "Kiosque Lac", address: "Les Berges du Lac", latitude: 36.8335, longitude: 10.2278, openingHoursText: "08:00 - 20:00" },
];

(async () => {
  for (const { id, ...data } of chargers) await db.collection("ev_chargers").doc(id).set(data);
  for (const { id, ...data } of kiosks) await db.collection("kiosk").doc(id).set(data);
  console.log(`Seeded ${chargers.length} chargers and ${kiosks.length} kiosks into the emulator.`);
})().catch((e) => { console.error(e); process.exit(1); });
