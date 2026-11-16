/**
 * Firestore security rules tests. Run inside the emulator:
 *   npx firebase emulators:exec --only firestore --project demo-chargi \
 *     "npm run test:rules"
 */
import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField } from "firebase/firestore";

let env: RulesTestEnvironment;

before(async () => {
  const [host, port] = (process.env["FIRESTORE_EMULATOR_HOST"] ?? "").split(":");
  env = await initializeTestEnvironment({
    projectId: "demo-chargi-rules",
    firestore: {
      rules: readFileSync(join(__dirname, "../../../firestore.rules"), "utf8"),
      host,
      port: Number(port),
    },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "reservations/r1"), { userId: "alice", chargerId: "c", status: "confirmed" });
    await setDoc(doc(db, "users/alice/reservations/r1"), { userId: "alice", status: "confirmed" });
    await setDoc(doc(db, "ev_chargers/c"), { name: "C", isActive: true });
    await setDoc(doc(db, "kiosk/k"), { name: "K" });
    await setDoc(doc(db, "notifications/n1"), { userId: "alice", read: false, title: "t" });
    await setDoc(doc(db, "connector_locks/c_1"), { rev: 1 });
    await setDoc(doc(db, "reports/p1"), { userId: "alice" });
  });
});

test("reservations: owner reads, others and anonymous cannot", async () => {
  await assertSucceeds(getDoc(doc(env.authenticatedContext("alice").firestore(), "reservations/r1")));
  await assertFails(getDoc(doc(env.authenticatedContext("bob").firestore(), "reservations/r1")));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "reservations/r1")));
});

test("reservations: nobody can write from the client, even the owner", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  await assertFails(setDoc(doc(alice, "reservations/new"), { userId: "alice" }));
  await assertFails(updateDoc(doc(alice, "reservations/r1"), { status: "cancelled" }));
  await assertFails(deleteDoc(doc(alice, "reservations/r1")));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), "reservations/x"), { a: 1 }));
});

test("user reservation mirror: owner reads, nobody writes", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(alice, "users/alice/reservations/r1")));
  await assertFails(getDoc(doc(env.authenticatedContext("bob").firestore(), "users/alice/reservations/r1")));
  await assertFails(setDoc(doc(alice, "users/alice/reservations/r2"), { a: 1 }));
  await assertFails(updateDoc(doc(alice, "users/alice/reservations/r1"), { status: "cancelled" }));
});

test("chargers and kiosks: public read, no client write", async () => {
  const anon = env.unauthenticatedContext().firestore();
  const alice = env.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(anon, "ev_chargers/c")));
  await assertSucceeds(getDoc(doc(anon, "kiosk/k")));
  await assertFails(updateDoc(doc(alice, "ev_chargers/c"), { isActive: false }));
  await assertFails(setDoc(doc(anon, "ev_chargers/evil"), { a: 1 }));
  await assertFails(setDoc(doc(alice, "kiosk/evil"), { a: 1 }));
});

test("profile and reports stay owner-only", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  await assertSucceeds(setDoc(doc(alice, "users/alice"), { name: "A", role: "user" }));
  await assertSucceeds(setDoc(doc(alice, "users/alice/reports/x"), { a: 1 }));
  await assertFails(getDoc(doc(bob, "users/alice")));
  await assertFails(setDoc(doc(bob, "users/alice/reports/y"), { a: 1 }));
});

test("notifications: owner reads and can only flip `read`", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  await assertSucceeds(getDoc(doc(alice, "notifications/n1")));
  await assertFails(getDoc(doc(bob, "notifications/n1")));
  await assertSucceeds(updateDoc(doc(alice, "notifications/n1"), { read: true }));
  await assertFails(updateDoc(doc(alice, "notifications/n1"), { title: "hacked" }));
  await assertFails(setDoc(doc(alice, "notifications/forged"), { userId: "alice", read: false }));
  await assertFails(deleteDoc(doc(alice, "notifications/n1")));
});

test("locks and top-level reports are closed", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  await assertFails(getDoc(doc(alice, "chat_rate/alice")));
  await assertFails(setDoc(doc(alice, "chat_rate/alice"), { minuteCount: 0, dayCount: 0 })); // cannot reset own LLM quota
  await assertFails(getDoc(doc(alice, "connector_locks/c_1")));
  await assertFails(setDoc(doc(alice, "connector_locks/c_1"), { rev: 0 }));
  await assertFails(getDoc(doc(alice, "reports/p1")));
  await assertFails(setDoc(doc(alice, "reports/p2"), { a: 1 }));
});

// ---- Roles -----------------------------------------------------------------

/** Writes a user document bypassing the rules (what the console / Admin SDK does). */
async function seedUser(uid: string, data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), data);
  });
}

test("roles: sign-up creates the profile with role 'user' only", async () => {
  const carol = env.authenticatedContext("carol").firestore();
  await assertSucceeds(setDoc(doc(carol, "users/carol"), { name: "C", email: "c@x.test", role: "user" }));
  // merge:true is what the app uses; on a new document it is a create
  const dan = env.authenticatedContext("dan").firestore();
  await assertSucceeds(setDoc(doc(dan, "users/dan"), { name: "D", role: "user" }, { merge: true }));
});

test("roles: nobody can create their profile as worker, admin, anything else, or without a role", async () => {
  const eve = env.authenticatedContext("eve").firestore();
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E", role: "worker" }));
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E", role: "admin" }));
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E", role: "superuser" }));
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E", role: "User" }));
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E" }));
  await assertFails(setDoc(doc(eve, "users/eve"), { name: "E", role: "worker" }, { merge: true }));
});

test("roles: a user can still edit name and phone", async () => {
  await seedUser("frank", { name: "F", email: "f@x.test", role: "user" });
  const frank = env.authenticatedContext("frank").firestore();
  await assertSucceeds(updateDoc(doc(frank, "users/frank"), { name: "Frank", phoneNumber: "+21612345678" }));
  // The exact write the Edit Profile screen performs (set + merge, role untouched)
  await assertSucceeds(setDoc(doc(frank, "users/frank"), { name: "Frank 2", email: "f@x.test", phoneNumber: "+21600000000" }, { merge: true }));
  assert.equal((await getDoc(doc(frank, "users/frank"))).get("role"), "user");
});

test("roles: a user cannot promote themselves (update, set, merge)", async () => {
  await seedUser("gina", { name: "G", role: "user" });
  const gina = env.authenticatedContext("gina").firestore();
  await assertFails(updateDoc(doc(gina, "users/gina"), { role: "worker" }));
  await assertFails(updateDoc(doc(gina, "users/gina"), { role: "admin" }));
  await assertFails(setDoc(doc(gina, "users/gina"), { name: "G", role: "worker" }, { merge: true }));
  await assertFails(setDoc(doc(gina, "users/gina"), { name: "G", role: "worker" }));
  // sneaking the change in alongside a legitimate edit is refused as a whole
  await assertFails(updateDoc(doc(gina, "users/gina"), { name: "Gina", role: "worker" }));
  assert.equal((await getDoc(doc(gina, "users/gina"))).get("role"), "user");
});

test("roles: a worker cannot change or remove their own role either", async () => {
  await seedUser("hugo", { name: "H", role: "worker" });
  const hugo = env.authenticatedContext("hugo").firestore();
  await assertFails(updateDoc(doc(hugo, "users/hugo"), { role: "admin" }));
  await assertFails(updateDoc(doc(hugo, "users/hugo"), { role: "user" }));
  await assertFails(updateDoc(doc(hugo, "users/hugo"), { role: deleteField() }));
  await assertSucceeds(updateDoc(doc(hugo, "users/hugo"), { name: "Hugo" })); // but still edits the profile
  assert.equal((await getDoc(doc(hugo, "users/hugo"))).get("role"), "worker");
});

test("roles: an older account without a role can edit its profile but cannot add a role", async () => {
  await seedUser("iris", { name: "I", email: "i@x.test" }); // legacy: no role field
  const iris = env.authenticatedContext("iris").firestore();
  await assertSucceeds(updateDoc(doc(iris, "users/iris"), { name: "Iris", phoneNumber: "+216" }));
  await assertSucceeds(setDoc(doc(iris, "users/iris"), { name: "Iris", phoneNumber: "+216" }, { merge: true }));
  await assertFails(updateDoc(doc(iris, "users/iris"), { role: "worker" }));
  await assertFails(setDoc(doc(iris, "users/iris"), { role: "admin" }, { merge: true }));
});

test("roles: profiles cannot be deleted or touched by other users", async () => {
  await seedUser("jack", { name: "J", role: "worker" });
  const jack = env.authenticatedContext("jack").firestore();
  const kim = env.authenticatedContext("kim").firestore();
  await assertFails(deleteDoc(doc(jack, "users/jack"))); // no erase-and-recreate trick
  await assertFails(updateDoc(doc(kim, "users/jack"), { name: "hacked" }));
  await assertFails(updateDoc(doc(kim, "users/jack"), { role: "user" }));
  await assertFails(setDoc(doc(kim, "users/jack"), { name: "x", role: "user" }));
  await assertFails(getDoc(doc(kim, "users/jack")));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), "users/jack"), { role: "user" }));
});

test("roles: an admin promotes someone from the console (Admin SDK path), and the user then reads it", async () => {
  await seedUser("lena", { name: "L", role: "user" });
  await seedUser("lena", { name: "L", role: "worker" }); // what the console does: bypasses rules
  const lena = env.authenticatedContext("lena").firestore();
  assert.equal((await getDoc(doc(lena, "users/lena"))).get("role"), "worker");
});

// ---- Rewards (added on main by the team, kept after the merge) --------------

test("rewards: own reward history and promo codes are private; points are editable but never together with the role", async () => {
  await seedUser("zoe", { name: "Z", role: "user", rewardPoints: 0 });
  const zoe = env.authenticatedContext("zoe").firestore();
  const other = env.authenticatedContext("other").firestore();

  await assertSucceeds(setDoc(doc(zoe, "users/zoe/reward_history/h1"), { points: 10 }));
  await assertSucceeds(getDoc(doc(zoe, "users/zoe/reward_history/h1")));
  await assertFails(getDoc(doc(other, "users/zoe/reward_history/h1")));
  await assertFails(setDoc(doc(other, "users/zoe/reward_history/h2"), { points: 999 }));
  await assertSucceeds(setDoc(doc(zoe, "users/zoe/promo_codes/p1"), { code: "PROMO30" }));
  await assertFails(getDoc(doc(other, "users/zoe/promo_codes/p1")));

  // the app writes rewardPoints through set+merge: allowed, role untouched
  await assertSucceeds(setDoc(doc(zoe, "users/zoe"), { rewardPoints: 20 }, { merge: true }));
  // ...but a role can never ride along with it
  await assertFails(setDoc(doc(zoe, "users/zoe"), { rewardPoints: 20, role: "admin" }, { merge: true }));
});
