import { type Card, readCards, signProfilePhotos } from "./photos.ts";

type Configuration = {
  projectURL: string;
  publicKey: string;
  adminKey: string;
};
type Command =
  | { action: "feed" }
  | { action: "visibility"; enabled: boolean }
  | { action: "decide"; target_id: string; choice: "connect" | "pass" }
  | { action: "block"; target_id: string };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const states = [
  "ready",
  "hidden",
  "needs_profile",
  "needs_photo",
  "needs_review",
  "restricted",
];

/** Auth supplies the caller; request bodies cannot select an identity or photo path. */
export function createDiscoveryHandler(
  config: Configuration,
  send: typeof fetch = fetch,
) {
  const adminHeaders = {
    apikey: config.adminKey,
    Authorization: `Bearer ${config.adminKey}`,
    "Content-Type": "application/json",
  };
  const rpc = (name: string, body: Record<string, unknown>) =>
    send(`${config.projectURL}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15_000),
    });
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return reply(405, { error: "Method not allowed" });
    }
    const authorization = request.headers.get("Authorization");
    if (!authorization || !/^Bearer \S+$/i.test(authorization)) {
      return reply(401, { error: "Sign in first" });
    }
    try {
      const identity = await send(`${config.projectURL}/auth/v1/user`, {
        headers: { apikey: config.publicKey, Authorization: authorization },
        signal: AbortSignal.timeout(15_000),
      });
      if ([401, 403].includes(identity.status)) {
        return reply(401, { error: "Sign in first" });
      }
      if (!identity.ok) {
        return reply(503, { error: "Account service unavailable" });
      }
      const user = await identity.json();
      if (typeof user.id !== "string" || !uuid.test(user.id)) {
        throw new Error("Invalid identity");
      }
      const person = user.id.toLowerCase();
      const command = parseCommand(await request.text());
      if (!command) return reply(400, { error: "Invalid discovery request" });
      let mutation: Response | undefined;
      switch (command.action) {
        case "visibility":
          mutation = await rpc("pilot_discovery_visibility", {
            person,
            enabled: command.enabled,
          });
          break;
        case "decide":
          mutation = await rpc("pilot_discovery_decide", {
            person,
            target: command.target_id,
            decision: command.choice,
          });
          break;
        case "block":
          mutation = await rpc("pilot_discovery_block", {
            person,
            target: command.target_id,
          });
          break;
      }
      if (mutation && !mutation.ok) {
        return reply(mutation.status === 400 ? 409 : 503, {
          error: "Could not update discovery. Refresh and try again.",
        });
      }
      const response = await rpc("pilot_discovery_feed", { person });
      if (!response.ok) throw new Error("Feed unavailable");
      const feed = await response.json();
      if (!states.includes(feed.state) || typeof feed.visible !== "boolean") {
        throw new Error("Invalid feed");
      }
      const candidates = readCards(feed.candidates, 20);
      const matches = readCards(feed.matches, 50);
      if (feed.state !== "ready" && (candidates.length || matches.length)) {
        throw new Error("Ineligible feed");
      }
      const urls = await signProfilePhotos(
        [...candidates, ...matches],
        config.projectURL,
        adminHeaders,
        send,
      );
      const present = (card: Card) => ({
        ...card,
        photo_url: urls.get(`${card.id}/profile.jpg`),
      });
      return reply(200, {
        state: feed.state,
        visible: feed.visible,
        candidates: candidates.map(present),
        matches: matches.map(present),
      });
    } catch {
      return reply(503, { error: "Discovery unavailable. Please try again." });
    }
  };
}

function parseCommand(text: string): Command | undefined {
  if (text.length > 1024) return;
  let value;
  try {
    value = JSON.parse(text);
  } catch {
    return;
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) return;
  const keys = Object.keys(value).sort().join(",");
  if (value.action === "feed" && keys === "action") return value;
  if (
    value.action === "visibility" && keys === "action,enabled" &&
    typeof value.enabled === "boolean"
  ) return value;
  if (
    ["decide", "block"].includes(value.action) &&
    typeof value.target_id === "string" && uuid.test(value.target_id)
  ) {
    if (value.action === "block" && keys === "action,target_id") return value;
    if (
      value.action === "decide" && keys === "action,choice,target_id" &&
      ["connect", "pass"].includes(value.choice)
    ) return value;
  }
}

function reply(status: number, value: unknown): Response {
  return Response.json(value, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}
