import { InfoTopic, Intent, Lang, Understanding } from "./types";
import { addDays, isValidDate, isValidTime, todayLocal, weekdayOf } from "./time";

/**
 * Deterministic (rule-based) language understanding, English + French.
 * Used when no LLM is configured. It is NOT an AI: it only recognises the
 * phrasings below.
 */

const normalize = (s: string): string =>
  s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[’']/g, " ")
    .replace(/(?<=[a-z])-(?=[a-z])/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const FR_MARKERS =
  /\b(je|veux|voudrais|mes|mon|ma|une|les|des|borne|bornes|reserver|annuler|annule|demain|aujourd|bonjour|salut|heure|heures|pendant|pres|cherche|trouver|disponible|disponibles|modifier|decaler|combien|tarif|prix|merci|s il|svp|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|ce soir|apres)\b/;

export function detectLang(text: string, previous?: Lang): Lang {
  const t = normalize(text);
  if (FR_MARKERS.test(t)) return "fr";
  // Short neutral answers ("14h", "yes") keep the previous language.
  return previous ?? "en";
}

const WEEKDAYS: Record<string, number> = {
  sunday: 0, dimanche: 0,
  monday: 1, lundi: 1,
  tuesday: 2, mardi: 2,
  wednesday: 3, mercredi: 3,
  thursday: 4, jeudi: 4,
  friday: 5, vendredi: 5,
  saturday: 6, samedi: 6,
};

interface Extracted<T> {
  value?: T;
  rest: string;
}

/**
 * French clock times written with "heures": "a 14 heures", "vers 9 heures 30".
 * Must run BEFORE duration extraction, otherwise "14 heures" is read as a
 * 14-hour duration. A duration is introduced by pour/pendant, a time by a/vers.
 */
function extractClockHeures(t: string): Extracted<string> {
  const m = /\b(?:a|vers)\s+(\d{1,2})\s*heures?(?:\s*(\d{2}))?\b/.exec(t);
  if (!m) return { rest: t };
  const hh = Number(m[1]);
  const mm = m[2] ? Number(m[2]) : 0;
  const value = `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
  if (!isValidTime(value)) return { rest: t };
  return { value, rest: (t.slice(0, m.index) + " " + t.slice(m.index + m[0].length)).trim() };
}

function extractDuration(t: string): Extracted<number> {
  const patterns: [RegExp, (m: RegExpExecArray) => number][] = [
    [/\b(?:for|pour|pendant|during|duree(?: de)?)?\s*(\d+(?:[.,]\d+)?)\s*(?:hours?|hrs?|heures?)\b/, (m) => Math.round(parseFloat(m[1].replace(",", ".")) * 60)],
    [/\b(?:for|pour|pendant|during|duree(?: de)?)\s*(\d+(?:[.,]\d+)?)\s*h\b/, (m) => Math.round(parseFloat(m[1].replace(",", ".")) * 60)],
    [/\b(\d+)\s*(?:minutes?|mins?|mn)\b/, (m) => parseInt(m[1], 10)],
    [/\b(?:half an hour|half hour|demi heure|une demi heure)\b/, () => 30],
    [/\b(?:an hour|one hour|une heure|1 heure)\b/, () => 60],
  ];
  for (const [re, fn] of patterns) {
    const m = re.exec(t);
    if (m) return { value: fn(m), rest: (t.slice(0, m.index) + " " + t.slice(m.index + m[0].length)).trim() };
  }
  return { rest: t };
}

function extractTime(t: string): Extracted<string> {
  const to24 = (h: number, mi: number, ap?: string): string | undefined => {
    if (ap === "pm" && h < 12) h += 12;
    if (ap === "am" && h === 12) h = 0;
    const s = `${String(h).padStart(2, "0")}:${String(mi).padStart(2, "0")}`;
    return isValidTime(s) ? s : undefined;
  };
  const patterns: [RegExp, (m: RegExpExecArray) => string | undefined][] = [
    [/\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/, (m) => to24(+m[1], m[2] ? +m[2] : 0, m[3])],
    [/\b(\d{1,2})\s*h\s*(\d{2})?\b/, (m) => to24(+m[1], m[2] ? +m[2] : 0)],
    [/\b(\d{1,2}):(\d{2})\b/, (m) => to24(+m[1], +m[2])],
    [/\b(?:at|a|vers)\s+(\d{1,2})\b(?!\s*(?:min|hour|heure|h\b|jan|fev|mar|avr|mai|juin|juil|aout|sep|oct|nov|dec))/, (m) => to24(+m[1], 0)],
    [/\b(?:noon|midi)\b/, () => "12:00"],
    [/\b(?:midnight|minuit)\b/, () => "00:00"],
  ];
  for (const [re, fn] of patterns) {
    const m = re.exec(t);
    if (m) {
      const value = fn(m);
      if (value) return { value, rest: (t.slice(0, m.index) + " " + t.slice(m.index + m[0].length)).trim() };
    }
  }
  return { rest: t };
}

function extractDate(t: string, nowMs: number, offsetMin: number): string | undefined {
  const today = todayLocal(nowMs, offsetMin);
  if (/\b(?:day after tomorrow|apres demain)\b/.test(t)) return addDays(today, 2);
  if (/\b(?:tomorrow|demain)\b/.test(t)) return addDays(today, 1);
  if (/\b(?:today|aujourd ?hui|tonight|ce soir)\b/.test(t)) return today;

  const iso = /\b(\d{4})-(\d{2})-(\d{2})\b/.exec(t);
  if (iso && isValidDate(iso[0])) return iso[0];

  const dmy = /\b(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\b/.exec(t);
  if (dmy) {
    const year = dmy[3] ? (dmy[3].length === 2 ? 2000 + +dmy[3] : +dmy[3]) : +today.slice(0, 4);
    const s = `${year}-${String(+dmy[2]).padStart(2, "0")}-${String(+dmy[1]).padStart(2, "0")}`;
    if (isValidDate(s)) return s;
  }

  for (const [name, wd] of Object.entries(WEEKDAYS)) {
    if (new RegExp(`\\b${name}\\b`).test(t)) {
      const delta = (wd - weekdayOf(today) + 7) % 7 || 7;
      return addDays(today, delta);
    }
  }
  return undefined;
}

function detectInfoTopic(t: string): InfoTopic | undefined {
  if (/\b(price|prices|pricing|tarif|tarifs|prix|cost|cout|how much|combien)\b/.test(t)) return "pricing";
  if (/\b(condition|conditions|policy|policies|rules?|regles?|how far|in advance|a l avance)\b/.test(t)) return "conditions";
  if (/\b(status|statuses|statut|statuts)\b/.test(t)) return "statuses";
  if (/\b(connector|connectors|connecteur|connecteurs|plug|prise|prises|type 2|ccs|chademo)\b/.test(t)) return "connectors";
  if (/\b(power|puissance|kw|kilowatt)\b/.test(t)) return "power";
  if (/\b(how does|how do|comment ca marche|comment ca fonctionne|how it works|fonctionnement)\b/.test(t)) return "how_it_works";
  return undefined;
}

function detectIntent(t: string): { intent: Intent; infoTopic?: InfoTopic } {
  if (/\b(cancel|annul\w*|supprim\w*)\b/.test(t)) return { intent: "cancel" };
  if (
    /\b(reschedul\w*|postpone|modif\w*|decal\w*|deplac\w*|reporter|move)\b/.test(t) ||
    /\b(change|changer)\b.*\b(booking|reservation|time|heure|creneau|date)\b/.test(t)
  ) {
    return { intent: "reschedule" };
  }
  if (
    /\b(my|mes|mon)\b.*\b(reservations?|bookings?)\b/.test(t) ||
    /\b(show|list|see|view|montre\w*|affiche\w*|voir|consult\w*)\b.*\b(reservations?|bookings?)\b/.test(t) ||
    /\b(upcoming|a venir)\b/.test(t)
  ) {
    return { intent: "list" };
  }
  const topic = detectInfoTopic(t);
  if (topic && topic !== "connectors" && topic !== "power") return { intent: "info", infoTopic: topic };
  if (/\b(book|booking|reserve|reserver|reservation|booker)\b/.test(t)) return { intent: "book" };
  if (
    /\b(find|search|look for|nearest|nearby|near|closest|cherch\w*|trouv\w*|proche|plus proche|pres de|available|disponibles?)\b/.test(t) &&
    /\b(charger|chargers|station|stations|borne|bornes|chargeur|chargeurs|charging)\b/.test(t)
  ) {
    return { intent: "find" };
  }
  if (/\b(nearest|nearby|closest|plus proche|pres de moi|near me)\b/.test(t)) return { intent: "find" };
  if (topic) return { intent: "info", infoTopic: topic };
  if (/^(hi|hello|hey|salut|bonjour|bonsoir|coucou|good morning|good evening)\b/.test(t)) {
    return { intent: "greeting" };
  }
  return { intent: "unknown" };
}

export function understandRules(
  text: string,
  nowMs: number,
  offsetMin: number,
): Understanding {
  const t0 = normalize(text);
  const { intent, infoTopic } = detectIntent(t0);

  const clock = extractClockHeures(t0);
  const dur = extractDuration(clock.rest);
  const time = clock.value ? { value: clock.value, rest: dur.rest } : extractTime(dur.rest);
  const date = extractDate(time.rest, nowMs, offsetMin);

  const u: Understanding = { intent };
  if (infoTopic) u.infoTopic = infoTopic;
  if (date) u.date = date;
  if (time.value) u.time = time.value;
  if (dur.value !== undefined) u.durationMinutes = dur.value;
  if (/\b(near me|nearby|nearest|closest|around me|pres de moi|proche de moi|a proximite|plus proche)\b/.test(t0)) {
    u.nearMe = true;
  }
  if (/\b(all|history|past|historique|toutes|tous)\b/.test(t0)) u.includeAll = true;
  return u;
}
