import { jsonReply } from "./http.ts";

export type AuthConfiguration = { projectURL: string; publicKey: string };
export const isUUID = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

/** Resolve a live Auth identity; decoded claims and request bodies are not identity. */
export async function authenticate(
  request: Request,
  config: AuthConfiguration,
  send: typeof fetch,
): Promise<{ userID: string; authorization: string } | Response> {
  const authorization = request.headers.get("Authorization");
  if (!authorization || !/^Bearer \S+$/i.test(authorization)) {
    return jsonReply(401, { error: "Sign in first" });
  }
  const response = await send(`${config.projectURL}/auth/v1/user`, {
    headers: { apikey: config.publicKey, Authorization: authorization },
    signal: AbortSignal.timeout(15_000),
  });
  if ([401, 403].includes(response.status)) {
    return jsonReply(401, { error: "Sign in first" });
  }
  if (!response.ok) {
    return jsonReply(503, { error: "Account service unavailable" });
  }
  const user = await response.json();
  if (!isUUID(user?.id)) {
    return jsonReply(503, { error: "Account service unavailable" });
  }
  return { userID: user.id.toLowerCase(), authorization };
}
