import { test } from "node:test";
import assert from "node:assert/strict";

import { detectLang, understandRules } from "../src/chatbot/nlu_rules";
import { buildNlu } from "../src/chatbot/engine";
import { sanitize, understandWithLlm, ParseClient } from "../src/chatbot/nlu_llm";

// Monday 2026-06-01 10:00 UTC, user in UTC+1 (local 11:00).
const NOW = Date.UTC(2026, 5, 1, 10, 0, 0);
const OFFSET = 60;
const u = (text: string) => understandRules(text, NOW, OFFSET);

test("rules: intents (English)", () => {
  assert.equal(u("I want to book a station tomorrow at 14:00").intent, "book");
  assert.equal(u("Show me my upcoming reservations").intent, "list");
  assert.equal(u("Cancel my reservation for tomorrow").intent, "cancel");
  assert.equal(u("Can I change my booking to 16:00?").intent, "reschedule");
  assert.equal(u("Reschedule my reservation").intent, "reschedule");
  assert.equal(u("Find available chargers").intent, "find");
  assert.equal(u("Find the nearest charging station").intent, "find");
  assert.equal(u("hello").intent, "greeting");
  assert.equal(u("asdf qwerty").intent, "unknown");
});

test("rules: intents (French)", () => {
  assert.equal(u("Je veux réserver une borne demain à 14h").intent, "book");
  assert.equal(u("Montre-moi mes réservations").intent, "list");
  assert.equal(u("Annuler ma réservation de demain").intent, "cancel");
  assert.equal(u("Je veux modifier ma réservation").intent, "reschedule");
  assert.equal(u("Je cherche une borne disponible près de moi").intent, "find");
  assert.equal(u("bonjour").intent, "greeting");
});

test("rules: info topics", () => {
  assert.deepEqual([u("What are the prices?").intent, u("What are the prices?").infoTopic], ["info", "pricing"]);
  assert.equal(u("Quels sont les tarifs ?").infoTopic, "pricing");
  assert.equal(u("How much does it cost?").infoTopic, "pricing");
  assert.equal(u("What connector types do you have?").infoTopic, "connectors");
  assert.equal(u("What power do the chargers have?").infoTopic, "power");
  assert.equal(u("What are the reservation conditions?").infoTopic, "conditions");
  assert.equal(u("What do the reservation statuses mean?").infoTopic, "statuses");
  assert.equal(u("How does it work?").infoTopic, "how_it_works");
});

test("rules: dates, times and durations", () => {
  const a = u("Book a station tomorrow at 14:00 for 2 hours");
  assert.deepEqual([a.date, a.time, a.durationMinutes], ["2026-06-02", "14:00", 120]);

  const b = u("Je veux réserver demain à 14h pendant 90 minutes");
  assert.deepEqual([b.date, b.time, b.durationMinutes], ["2026-06-02", "14:00", 90]);

  assert.equal(u("today at 9:30").date, "2026-06-01");
  assert.equal(u("2pm").time, "14:00");
  assert.equal(u("12am").time, "00:00");
  assert.equal(u("à 9h30").time, "09:30");
  assert.equal(u("at 14").time, "14:00");
  assert.equal(u("friday").date, "2026-06-05");
  assert.equal(u("lundi").date, "2026-06-08"); // today is Monday: next one
  assert.equal(u("après-demain").date, "2026-06-03");
  assert.equal(u("on 2026-06-12").date, "2026-06-12");
  assert.equal(u("on 12/06").date, "2026-06-12");
  assert.equal(u("1 hour").durationMinutes, 60);
  assert.equal(u("30 minutes").durationMinutes, 30);
  assert.equal(u("half an hour").durationMinutes, 30);
});

test("rules: a duration is not mistaken for a time, and junk gives nothing", () => {
  const x = u("for 2 hours");
  assert.equal(x.durationMinutes, 120);
  assert.equal(x.time, undefined);
  assert.equal(u("25:99").time, undefined);
  assert.equal(u("hello there").date, undefined);
});

test("rules: near-me flag and language detection", () => {
  assert.equal(u("Find a charger near me").nearMe, true);
  assert.equal(u("Find the nearest charging station").nearMe, true);
  assert.equal(u("Find available chargers").nearMe, undefined);
  assert.equal(detectLang("Je veux réserver"), "fr");
  assert.equal(detectLang("I want to book"), "en");
  assert.equal(detectLang("14:00", "fr"), "fr"); // neutral answers keep language
});

// ---- LLM adapter (with a fake client: no network, no key) ------------------

const fakeParse = (parsed: unknown, stop = "end_turn"): ParseClient => ({
  messages: { parse: async () => ({ parsed_output: parsed as never, stop_reason: stop }) },
});

test("llm: maps structured output and re-validates every field", async () => {
  const client = fakeParse({
    intent: "book", date: "2026-06-02", time: "14:00", duration_minutes: 120,
    near_me: false, info_topic: null, include_all: false,
  });
  const out = await understandWithLlm(client, "book tomorrow 2pm 2h", NOW, OFFSET);
  assert.deepEqual(out, { intent: "book", date: "2026-06-02", time: "14:00", durationMinutes: 120 });

  const bad = sanitize({
    intent: "book", date: "2026-13-45", time: "99:99", duration_minutes: -5,
    near_me: false, info_topic: null, include_all: false,
  });
  assert.deepEqual(bad, { intent: "book" }); // invalid values dropped, never trusted
});

test("llm: sends the local date in the system prompt and never forces a tool", async () => {
  let seen: Record<string, unknown> = {};
  const client: ParseClient = {
    messages: {
      parse: async (params) => {
        seen = params;
        return { parsed_output: { intent: "list", date: null, time: null, duration_minutes: null, near_me: false, info_topic: null, include_all: false }, stop_reason: "end_turn" };
      },
    },
  };
  await understandWithLlm(client, "my reservations", NOW, OFFSET, "claude-opus-5-5");
  assert.equal(seen["model"], "claude-opus-5-5");
  assert.match(String(seen["system"]), /Current local date: 2026-06-01/);
  assert.equal(seen["tool_choice"], undefined);
  assert.equal(seen["temperature"], undefined);
});

test("engine: uses the LLM when available and labels it", async () => {
  const nlu = buildNlu({
    client: fakeParse({ intent: "list", date: null, time: null, duration_minutes: null, near_me: false, info_topic: null, include_all: false }),
  });
  const r = await nlu("whatever", NOW, OFFSET);
  assert.equal(r.engine, "llm");
  assert.equal(r.understanding.intent, "list");
});

test("engine: falls back to rules (and says so) when the LLM fails or refuses", async () => {
  const failing: ParseClient = { messages: { parse: async () => { throw new Error("network"); } } };
  const logged: string[] = [];
  const a = await buildNlu({ client: failing, log: (m) => logged.push(m) })("Cancel my reservation", NOW, OFFSET);
  assert.equal(a.engine, "rules");
  assert.equal(a.understanding.intent, "cancel");
  assert.equal(logged.length, 1);

  const refused = await buildNlu({ client: fakeParse(null, "refusal") })("my reservations", NOW, OFFSET);
  assert.equal(refused.engine, "rules");
});

test("engine: without a key it is rules only", async () => {
  const r = await buildNlu({})("hello", NOW, OFFSET);
  assert.equal(r.engine, "rules");
});

// ---- Suggested quick replies must be understood by the engine --------------

import { t } from "../src/chatbot/i18n";

test("rules: every suggested quick reply maps to the intended intent (EN + FR)", () => {
  for (const lang of ["en", "fr"] as const) {
    const expected: [Parameters<typeof t>[1], string][] = [
      ["qrFind", "find"],
      ["qrBook", "book"],
      ["qrList", "list"],
      ["qrCancel", "cancel"],
      ["qrResched", "reschedule"],
      ["qrNearest", "find"],
    ];
    for (const [key, intent] of expected) {
      assert.equal(u(t(lang, key)).intent, intent, `${lang}:${key} -> ${t(lang, key)}`);
    }
    assert.equal(u(t(lang, "qr30")).durationMinutes, 30);
    assert.equal(u(t(lang, "qr60")).durationMinutes, 60);
    assert.equal(u(t(lang, "qr120")).durationMinutes, 120);
    assert.ok(u(t(lang, "qrToday")).date, `${lang}: today`);
    assert.ok(u(t(lang, "qrTomorrow")).date, `${lang}: tomorrow`);
  }
});

test("rules: French 'heures' is a time after à/vers, a duration after pendant/pour", () => {
  const a = u("Je veux réserver demain à 14 heures");
  assert.deepEqual([a.intent, a.date, a.time, a.durationMinutes], ["book", "2026-06-02", "14:00", undefined]);

  const b = u("demain à 14 heures pendant 2 heures");
  assert.deepEqual([b.time, b.durationMinutes], ["14:00", 120]);

  const c = u("pendant 2 heures demain à 9 heures 30");
  assert.deepEqual([c.time, c.durationMinutes], ["09:30", 120]);

  assert.equal(u("vers 18 heures").time, "18:00");
  const d = u("pour 3 heures");
  assert.deepEqual([d.time, d.durationMinutes], [undefined, 180]);
  assert.equal(u("à 25 heures").time, undefined); // invalid hour is not a time
  assert.equal(u("book a 2 hours slot").durationMinutes, 120); // English unaffected
});

// ---- LLM quota ---------------------------------------------------------------

test("engine: over the quota the LLM is not called and the rules answer", async () => {
  let llmCalls = 0;
  const counting: ParseClient = {
    messages: {
      parse: async () => {
        llmCalls++;
        return { parsed_output: { intent: "list", date: null, time: null, duration_minutes: null, near_me: false, info_topic: null, include_all: false }, stop_reason: "end_turn" };
      },
    },
  };
  const logged: string[] = [];

  const denied = await buildNlu({ client: counting, allowLlm: async () => false, log: (m) => logged.push(m) })("Cancel my reservation", NOW, OFFSET);
  assert.equal(denied.engine, "rules");
  assert.equal(denied.understanding.intent, "cancel");
  assert.equal(llmCalls, 0);
  assert.ok(logged.some((m) => m.includes("quota")));

  const allowed = await buildNlu({ client: counting, allowLlm: async () => true })("my reservations", NOW, OFFSET);
  assert.equal(allowed.engine, "llm");
  assert.equal(llmCalls, 1);
});

test("engine: if the quota check itself fails, no LLM money is spent", async () => {
  let llmCalls = 0;
  const counting: ParseClient = { messages: { parse: async () => { llmCalls++; return { parsed_output: null, stop_reason: "end_turn" }; } } };
  const r = await buildNlu({ client: counting, allowLlm: async () => { throw new Error("firestore down"); } })("hello", NOW, OFFSET);
  assert.equal(r.engine, "rules");
  assert.equal(llmCalls, 0);
});

test("engine: without an LLM client the quota is never consulted", async () => {
  let asked = 0;
  await buildNlu({ allowLlm: async () => { asked++; return true; } })("hello", NOW, OFFSET);
  assert.equal(asked, 0);
});
