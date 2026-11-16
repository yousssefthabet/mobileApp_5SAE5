/** Local-time helpers. All "local" values use a fixed offset in minutes east of UTC. */

const MIN = 60 * 1000;

export function clampOffset(offsetMinutes: unknown): number {
  const n = typeof offsetMinutes === "number" ? offsetMinutes : 0;
  if (!Number.isFinite(n)) return 0;
  return Math.max(-14 * 60, Math.min(14 * 60, Math.trunc(n)));
}

const pad = (n: number): string => String(n).padStart(2, "0");

export function formatLocal(ms: number, offsetMin: number): { date: string; time: string } {
  const d = new Date(ms + offsetMin * MIN);
  return {
    date: `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`,
    time: `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`,
  };
}

export function todayLocal(nowMs: number, offsetMin: number): string {
  return formatLocal(nowMs, offsetMin).date;
}

/** 0 = Sunday ... 6 = Saturday, for a local YYYY-MM-DD. */
export function weekdayOf(date: string): number {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + days));
  return `${dt.getUTCFullYear()}-${pad(dt.getUTCMonth() + 1)}-${pad(dt.getUTCDate())}`;
}

export function isValidDate(date: string): boolean {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d;
}

export function isValidTime(time: string): boolean {
  const m = /^(\d{2}):(\d{2})$/.exec(time);
  return !!m && Number(m[1]) < 24 && Number(m[2]) < 60;
}

/** Local date + time to a UTC instant (ms). Inputs must already be valid. */
export function localToUtcMs(date: string, time: string, offsetMin: number): number {
  const [y, mo, d] = date.split("-").map(Number);
  const [h, mi] = time.split(":").map(Number);
  return Date.UTC(y, mo - 1, d, h, mi) - offsetMin * MIN;
}
