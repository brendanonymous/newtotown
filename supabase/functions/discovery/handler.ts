import { type AgePreferences, agePreferences } from "./preferences.ts";
import { authenticate } from "../_shared/auth.ts";
import {
  type Card,
  profilePhotoURLs,
  readCards,
  signProfilePhotos,
} from "../_shared/profile-photos.ts";

type Configuration = {
  projectURL: string;
  publicKey: string;
  adminKey: string;
};
type Command =
  | { action: "feed" }
  | { action: "preferences" }
  | ({ action: "save_preferences" } & AgePreferences)
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
    try {
      const identity = await authenticate(request, config, send);
      if (identity instanceof Response) return identity;
      const person = identity.userID;
      const command = parseCommand(await request.text());
      if (!command) return reply(400, { error: "Invalid discovery request" });
      if (
        command.action === "preferences" ||
        command.action === "save_preferences"
      ) {
        const response = command.action === "preferences"
          ? await rpc("pilot_discovery_preferences", { person })
          : await rpc("pilot_discovery_save_preferences", {
            person,
            minimum_age: command.minimum_age,
            maximum_age: command.maximum_age,
          });
        if (!response.ok) throw new Error("Preferences unavailable");
        const preferences = agePreferences(await response.json());
        if (!preferences) throw new Error("Invalid preferences response");
        return reply(200, preferences);
      }
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
        photo_urls: profilePhotoURLs(card.id, urls),
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
  if (value.action === "preferences" && keys === "action") return value;
  if (
    value.action === "save_preferences" &&
    keys === "action,maximum_age,minimum_age" && agePreferences(value)
  ) return value;
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
