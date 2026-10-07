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
    const authorization = request.headers.get("Authorization");
    if (!authorization || !/^Bearer \S+$/i.test(authorization)) {
      return reply(401, "Sign in before deleting your account");
    }

    try {
      // A network lookup rejects expired tokens and accounts already deleted.
      // Merely decoding a JWT would not provide this guarantee.
      const identity = await send(`${authURL}/user`, {
        signal: AbortSignal.timeout(15_000),
        headers: {
          apikey: configuration.publicKey,
          Authorization: authorization,
        },
      });
      if (identity.status === 401 || identity.status === 403) {
        return reply(401, "Sign in before deleting your account");
      }
      if (!identity.ok) return reply(503, "Account service unavailable");
      const user = await identity.json();
      if (typeof user.id !== "string" || !/^[0-9a-f-]{36}$/i.test(user.id)) {
        return reply(503, "Account service unavailable");
      }

      const revoked = await send(`${authURL}/logout?scope=global`, {
        method: "POST",
        signal: AbortSignal.timeout(15_000),
        headers: {
          apikey: configuration.adminKey,
          Authorization: authorization,
        },
      });
      if (!revoked.ok) return reply(503, "Could not revoke account sessions");

      // Hard deletion cascades to profiles through the existing foreign key.
      // Add Storage cleanup here before introducing user-owned media.
      const deleted = await send(`${authURL}/admin/users/${user.id}`, {
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
        signal: AbortSignal.timeout(15_000),
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
