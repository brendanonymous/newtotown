import { authenticate } from "../_shared/auth.ts";
import { jsonReply, readJSON } from "../_shared/http.ts";
import { command, ownerInterests } from "./commands.ts";

type Configuration = {
  projectURL: string;
  publicKey: string;
  adminKey: string;
};
export function createInterestsHandler(
  config: Configuration,
  send: typeof fetch = fetch,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonReply(405, { error: "Method not allowed" });
    }
    try {
      const identity = await authenticate(request, config, send);
      if (identity instanceof Response) return identity;
      let action;
      try {
        action = command(await readJSON(request, 4096));
      } catch {
        return jsonReply(400, { error: "Invalid interests request" });
      }
      if (!action) {
        return jsonReply(400, { error: "Invalid interests request" });
      }
      const result = await send(
        `${config.projectURL}/rest/v1/rpc/${
          action.action === "load" ? "pilot_interests" : "pilot_interests_save"
        }`,
        {
          method: "POST",
          headers: {
            apikey: config.adminKey,
            Authorization: `Bearer ${config.adminKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(
            action.action === "load" ? { person: identity.userID } : {
              person: identity.userID,
              selection_kind: action.selection_kind,
              option_ids: action.option_ids,
            },
          ),
          signal: AbortSignal.timeout(15_000),
        },
      );
      if (!result.ok) {
        const failure = await result.json().catch(() => ({}));
        if (failure.code === "22023") {
          return jsonReply(400, {
            error: "Choose up to three available interests per category",
          });
        }
        if (failure.code === "P0001") {
          return jsonReply(404, { error: "Create your profile first" });
        }
        throw new Error("Interests unavailable");
      }
      return jsonReply(200, ownerInterests(await result.json()));
    } catch {
      return jsonReply(503, {
        error: "Could not load or save interests. Please try again.",
      });
    }
  };
}
