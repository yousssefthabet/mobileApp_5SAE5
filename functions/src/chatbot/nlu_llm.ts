import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

import { isValidDate, isValidTime, todayLocal, formatLocal } from "./time";
import { Understanding } from "./types";

/**
 * LLM-backed language understanding.
 *
 * The model ONLY turns a message into a structured intent + entities. It never
 * calls tools, never touches Firestore and never writes the reply text: the
 * dialogue engine validates the result and builds every answer from real data.
 */

const UnderstandingSchema = z.object({
  intent: z.enum(["find", "book", "list", "cancel", "reschedule", "info", "greeting", "unknown"]),
  date: z.string().nullable().describe("Local date YYYY-MM-DD, resolved from relative words, or null"),
  time: z.string().nullable().describe("Local 24h time HH:mm, or null"),
  duration_minutes: z.number().int().nullable(),
  near_me: z.boolean(),
  info_topic: z
    .enum(["pricing", "connectors", "power", "how_it_works", "conditions", "statuses"])
    .nullable(),
  include_all: z.boolean(),
});

const SYSTEM_PROMPT = `You extract structure from messages sent to Chargi's EV-charging reservation assistant.
Reply only with the requested JSON. Never answer the user.

Intents:
- find: wants to find or locate charging stations
- book: wants to make a reservation
- list: wants to see their reservations
- cancel: wants to cancel a reservation
- reschedule: wants to change the time of an existing reservation
- info: asks about prices, connector types, power, how it works, reservation conditions, or reservation statuses
- greeting: only a greeting
- unknown: anything else

Rules:
- Resolve relative dates ("tomorrow", "next Monday", "demain") to an absolute local date using the current local date below.
- Times are 24h HH:mm in the user's local time. Do not invent a date or time the user did not give: use null.
- For "reschedule", date/time describe the NEW slot.
- The message may be English or French.`;

/** Minimal shape of the SDK we rely on, so tests can inject a fake. */
export interface ParseClient {
  messages: {
    parse(params: Record<string, unknown>): Promise<{
      parsed_output?: z.infer<typeof UnderstandingSchema> | null;
      stop_reason?: string | null;
    }>;
  };
}

export function createAnthropicClient(apiKey: string): ParseClient {
  return new Anthropic({ apiKey }) as unknown as ParseClient;
}

export const DEFAULT_MODEL = "claude-opus-5-5";

export async function understandWithLlm(
  client: ParseClient,
  text: string,
  nowMs: number,
  offsetMin: number,
  model: string = DEFAULT_MODEL,
): Promise<Understanding> {
  const local = formatLocal(nowMs, offsetMin);
  const response = await client.messages.parse({
    model,
    max_tokens: 1024,
    system: `${SYSTEM_PROMPT}\n\nCurrent local date: ${todayLocal(nowMs, offsetMin)} (time ${local.time}).`,
    messages: [{ role: "user", content: text }],
    // Extraction is shallow work; the effort level is configurable in code.
    output_config: { effort: "low", format: zodOutputFormat(UnderstandingSchema) },
  });

  if (response.stop_reason === "refusal" || !response.parsed_output) {
    throw new Error("LLM returned no usable output");
  }
  return sanitize(response.parsed_output);
}

/** Never trust model output: re-validate every field. */
export function sanitize(p: z.infer<typeof UnderstandingSchema>): Understanding {
  const u: Understanding = { intent: p.intent };
  if (p.date && isValidDate(p.date)) u.date = p.date;
  if (p.time && isValidTime(p.time)) u.time = p.time;
  if (p.duration_minutes !== null && p.duration_minutes > 0 && p.duration_minutes <= 24 * 60) {
    u.durationMinutes = p.duration_minutes;
  }
  if (p.near_me) u.nearMe = true;
  if (p.info_topic) u.infoTopic = p.info_topic;
  if (p.include_all) u.includeAll = true;
  return u;
}
