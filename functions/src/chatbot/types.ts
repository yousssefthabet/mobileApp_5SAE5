import type { ChargerSearchResult } from "../reservations";

export type Intent =
  | "find"
  | "book"
  | "list"
  | "cancel"
  | "reschedule"
  | "info"
  | "greeting"
  | "unknown";

export type InfoTopic =
  | "pricing"
  | "connectors"
  | "power"
  | "how_it_works"
  | "conditions"
  | "statuses";

export type Lang = "en" | "fr";

/** What the NLU (rules or LLM) extracted from ONE user message. */
export interface Understanding {
  intent: Intent;
  /** Local date, YYYY-MM-DD. */
  date?: string;
  /** Local time, HH:mm (24h). */
  time?: string;
  durationMinutes?: number;
  nearMe?: boolean;
  infoTopic?: InfoTopic;
  /** Wants past reservations too (history) when listing. */
  includeAll?: boolean;
}

/**
 * Conversation context carried by the client and sent back every turn.
 * It is untrusted input: it only steers the dialogue. Every action still goes
 * through authenticated, transactional Cloud Functions.
 */
export interface ChatState {
  intent?: Intent;
  date?: string;
  time?: string;
  durationMinutes?: number;
  chargerId?: string;
  connectorId?: number;
  reservationId?: string;
  lang?: Lang;
}

export interface ChatContext {
  /** Minutes east of UTC (Dart: DateTime.now().timeZoneOffset.inMinutes). */
  tzOffsetMinutes: number;
  lat?: number;
  lng?: number;
}

export type ChatAction =
  | { type: "select_connector"; chargerId: string; connectorId: number }
  | { type: "select_reservation"; reservationId: string };

export interface ChatRequest {
  text?: string;
  action?: ChatAction;
  state?: ChatState;
  context?: ChatContext;
}

export interface ReservationSummary {
  id: string;
  stationName: string;
  connectorName: string;
  connectorId: number;
  start: string;
  end: string;
  durationMinutes: number;
  amount: number;
  currency: string;
  status: string;
}

export type Card =
  | { type: "chargers"; items: ChargerSearchResult[]; selectable: boolean }
  | {
      type: "reservations";
      items: ReservationSummary[];
      /** When set, the user can tap an item to pick it for this action. */
      selectable?: "cancel" | "reschedule";
    };

export type PendingAction =
  | {
      kind: "create";
      params: {
        chargerId: string;
        connectorId: number;
        start: string;
        durationMinutes: number;
      };
      summary: { label: string; value: string }[];
      amount: number;
      currency: string;
    }
  | {
      kind: "cancel";
      params: { reservationId: string };
      summary: { label: string; value: string }[];
    }
  | {
      kind: "reschedule";
      params: {
        reservationId: string;
        start: string;
        durationMinutes: number;
      };
      summary: { label: string; value: string }[];
      amount: number;
      currency: string;
    };

export interface ChatResponse {
  reply: string;
  state: ChatState;
  cards: Card[];
  /** Present when the assistant needs an explicit confirmation to proceed. */
  pending?: PendingAction;
  quickReplies: string[];
  /** The client should request location permission, then re-send the text. */
  needsLocation?: boolean;
  /** Which understanding engine produced this turn. */
  engine: "rules" | "llm";
}
