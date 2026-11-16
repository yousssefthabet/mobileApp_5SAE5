import { Nlu } from "./dialog";
import { createAnthropicClient, DEFAULT_MODEL, ParseClient, understandWithLlm } from "./nlu_llm";
import { understandRules } from "./nlu_rules";

/**
 * Chooses the understanding engine.
 *
 * With an Anthropic API key the LLM is used; if a call fails (network, quota,
 * refusal) the turn falls back to the deterministic rules and the response is
 * labelled `engine: "rules"`, so the app never pretends the LLM answered.
 * Without a key, only the rules engine runs.
 */
export function buildNlu(options: {
  apiKey?: string;
  model?: string;
  client?: ParseClient;
  /** Asked before every LLM call; false means 'over quota': use the rules. */
  allowLlm?: () => Promise<boolean>;
  log?: (msg: string, err: unknown) => void;
}): Nlu {
  const client = options.client ?? (options.apiKey ? createAnthropicClient(options.apiKey) : undefined);
  const model = options.model || DEFAULT_MODEL;

  return async (text, nowMs, offsetMin) => {
    if (client && (await isAllowed(options))) {
      try {
        const understanding = await understandWithLlm(client, text, nowMs, offsetMin, model);
        return { understanding, engine: "llm" };
      } catch (err) {
        options.log?.("LLM understanding failed, using rules", err);
      }
    }
    return { understanding: understandRules(text, nowMs, offsetMin), engine: "rules" };
  };
}

async function isAllowed(options: { allowLlm?: () => Promise<boolean>; log?: (msg: string, err: unknown) => void }): Promise<boolean> {
  if (!options.allowLlm) return true;
  try {
    const ok = await options.allowLlm();
    if (!ok) options.log?.("LLM quota reached, using rules", "quota");
    return ok;
  } catch (err) {
    // If the quota cannot be checked, do not spend LLM money.
    options.log?.("LLM quota check failed, using rules", err);
    return false;
  }
}
