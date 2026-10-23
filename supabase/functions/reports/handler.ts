import { authenticate, isUUID } from "../_shared/auth.ts";
import { jsonReply, readJSON } from "../_shared/http.ts";

type Configuration = {
  projectURL: string;
  publicKey: string;
  adminKey: string;
};
const reasons = new Set([
  "unwanted_contact",
  "inappropriate_content",
  "non_platonic",
  "spam",
  "other",
]);
type Command = {
  target_id: string;
  reason: string;
  details: string | null;
  client_report_id: string;
};

function command(value: unknown): Command | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const fields = value as Record<string, unknown>;
  if (
    Object.keys(fields).length !== 4 || !isUUID(fields.target_id) ||
    !isUUID(fields.client_report_id) || typeof fields.reason !== "string" ||
    !reasons.has(fields.reason) ||
    !(fields.details === null || typeof fields.details === "string" &&
        [...fields.details].length <= 1000 && !fields.details.includes("\0"))
  ) return null;
  // Construct explicitly: identities, review status, and timestamps cannot come from the client.
  return {
    target_id: fields.target_id,
    reason: fields.reason,
    details: fields.details,
    client_report_id: fields.client_report_id,
  };
}

export function createReportsHandler(
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
      let report: Command | null;
      try {
        report = command(await readJSON(request, 32_768));
      } catch {
        return jsonReply(400, { error: "Invalid report" });
      }
      if (!report || report.target_id.toLowerCase() === identity.userID) {
        return jsonReply(400, { error: "Invalid report" });
      }
      const result = await send(
        `${config.projectURL}/rest/v1/rpc/pilot_report_profile`,
        {
          method: "POST",
          headers: {
            apikey: config.adminKey,
            Authorization: `Bearer ${config.adminKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            person: identity.userID,
            target: report.target_id,
            report_reason: report.reason,
            report_details: report.details,
            retry_id: report.client_report_id,
          }),
          signal: AbortSignal.timeout(15_000),
        },
      );
      if (!result.ok) {
        const failure = await result.json().catch(() => ({}));
        if (failure.code === "P0001") {
          return jsonReply(404, { error: "Connection unavailable" });
        }
        if (failure.code === "23505") {
          return jsonReply(409, { error: "Retry conflict" });
        }
        if (failure.code === "22023") {
          return jsonReply(400, { error: "Invalid report" });
        }
        throw new Error("Report unavailable");
      }
      const receipt = await result.json();
      if (!isUUID(receipt?.id)) throw new Error("Invalid receipt");
      return jsonReply(200, { id: receipt.id });
    } catch {
      return jsonReply(503, {
        error: "Could not submit report. Please try again.",
      });
    }
  };
}
