import { authenticate } from "../_shared/auth.ts";
import { removePrivatePhotos } from "./photos.ts";

type Configuration = {
  projectURL: string;
  publicKey: string;
  adminKey: string;
};

/** No account ID is accepted from the request. Auth determines the only target. */
export function createDeleteAccountHandler(
  configuration: Configuration,
  send: typeof fetch = fetch,
): (request: Request) => Promise<Response> {
  const authURL = `${configuration.projectURL}/auth/v1`;

  return async (request) => {
    if (request.method !== "POST") {
      return reply(405, "Method not allowed", { Allow: "POST" });
    }
    try {
      const identity = await authenticate(request, configuration, send);
      if (identity instanceof Response) return identity;
      const { authorization, userID } = identity;

      const revoked = await send(`${authURL}/logout?scope=global`, {
        method: "POST",
        signal: AbortSignal.timeout(15_000),
        headers: {
          apikey: configuration.adminKey,
          Authorization: authorization,
        },
      });
      if (!revoked.ok) return reply(503, "Could not revoke account sessions");

      const removed = await removePrivatePhotos(
        configuration.projectURL,
        configuration.adminKey,
        userID,
        send,
      );
      if (!removed) return reply(503, "Photo cleanup could not be completed");

      // Hard deletion cascades to profile and consent through their foreign keys.
      const deleted = await send(`${authURL}/admin/users/${userID}`, {
        method: "DELETE",
        signal: AbortSignal.timeout(15_000),
        headers: {
          apikey: configuration.adminKey,
          Authorization: `Bearer ${configuration.adminKey}`,
        },
      });
      if (!deleted.ok) {
        return reply(503, "Account deletion could not be completed");
      }
      return new Response(null, {
        status: 204,
        headers: { "Cache-Control": "no-store" },
      });
    } catch {
      // Never return upstream errors, tokens, or configuration values to callers.
      return reply(503, "Account deletion could not be completed");
    }
  };
}

function reply(
  status: number,
  error: string,
  headers: Record<string, string> = {},
): Response {
  return Response.json({ error }, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
}
