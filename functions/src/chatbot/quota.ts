import { Firestore } from "firebase-admin/firestore";

/**
 * Per-user limit on LLM-backed messages, to cap cost and abuse.
 * Counters live in `chat_rate/{uid}`, which the security rules keep closed to
 * clients (only Cloud Functions touch it).
 */
export interface QuotaLimits {
  perMinute: number;
  perDay: number;
}

export const DEFAULT_LLM_LIMITS: QuotaLimits = { perMinute: 15, perDay: 300 };

const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

/**
 * Tries to spend one LLM call for [uid]. Returns false (and spends nothing)
 * when a limit is reached. Callers fall back to the rule-based engine.
 */
export async function consumeLlmQuota(
  db: Firestore,
  uid: string,
  nowMs: number,
  limits: QuotaLimits = DEFAULT_LLM_LIMITS,
): Promise<boolean> {
  const ref = db.collection("chat_rate").doc(uid);
  const minute = Math.floor(nowMs / MINUTE_MS);
  const day = Math.floor(nowMs / DAY_MS);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.exists ? (snap.data() as Record<string, unknown>) : {};
    const minuteCount = d["minute"] === minute ? Number(d["minuteCount"] ?? 0) : 0;
    const dayCount = d["day"] === day ? Number(d["dayCount"] ?? 0) : 0;

    if (minuteCount >= limits.perMinute || dayCount >= limits.perDay) return false;

    tx.set(ref, { minute, minuteCount: minuteCount + 1, day, dayCount: dayCount + 1 });
    return true;
  });
}
