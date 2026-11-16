/**
 * Upgrades reservations created by the first app version to the current
 * format (adds start, end, status, connectorKey) so they take part in the
 * overlap checks.
 *
 * Safe by default: it only PRINTS what it would change.
 *
 *   Emulator test run:
 *     FIRESTORE_EMULATOR_HOST=localhost:8185 node scripts/migrate-reservations.js
 *     FIRESTORE_EMULATOR_HOST=localhost:8185 node scripts/migrate-reservations.js --apply
 *
 *   Real project (needs admin credentials, e.g. `gcloud auth application-default login`):
 *     node scripts/migrate-reservations.js --project chargi-b044b            (dry run)
 *     node scripts/migrate-reservations.js --project chargi-b044b --apply   (writes!)
 *
 * Run `npm run build` first (it reuses the compiled reader from lib/).
 */
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { normalizeReservation } = require("../lib/src/domain");

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const projectIdx = args.indexOf("--project");
const project = projectIdx >= 0 ? args[projectIdx + 1] : undefined;
const emulator = !!process.env.FIRESTORE_EMULATOR_HOST;

if (!emulator && !project) {
  console.error("Not talking to the emulator: pass --project <id> explicitly.");
  process.exit(1);
}

initializeApp({ projectId: project || "chargi-b044b" });
const db = getFirestore();

(async () => {
  console.log(`Target: ${emulator ? "EMULATOR" : "REAL PROJECT " + project} | mode: ${apply ? "APPLY" : "dry run"}`);
  const snap = await db.collection("reservations").get();
  let needs = 0;
  let skipped = 0;
  let done = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const alreadyCurrent =
      d.start && d.end && typeof d.status === "string" && typeof d.connectorKey === "string";
    if (alreadyCurrent) continue;

    const n = normalizeReservation(d);
    if (!n || n.connectorKey === null) {
      skipped++;
      console.log(`  skip ${doc.id}: not enough data (needs start, duration and connector)`);
      continue;
    }
    needs++;
    const patch = {
      start: Timestamp.fromMillis(n.startMs),
      end: Timestamp.fromMillis(n.endMs),
      status: n.status,
      connectorKey: n.connectorKey,
    };
    console.log(`  ${apply ? "update" : "would update"} ${doc.id}: status=${n.status} connectorKey=${n.connectorKey}`);
    if (apply) {
      await doc.ref.update(patch);
      if (d.userId) {
        const mirror = db.collection("users").doc(d.userId).collection("reservations").doc(doc.id);
        if ((await mirror.get()).exists) await mirror.update(patch);
      }
      done++;
    }
  }
  console.log(`Total ${snap.size} | to upgrade ${needs} | skipped ${skipped} | written ${done}`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
