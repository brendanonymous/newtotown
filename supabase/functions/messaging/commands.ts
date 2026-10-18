import { isUUID } from "../_shared/auth.ts";

type Cursor = { time: string; id: string };
export type Command =
  | { action: "list"; cursor?: Cursor }
  | { action: "open"; target_id: string }
  | { action: "history"; conversation_id: string; cursor?: Cursor }
  | {
    action: "send";
    conversation_id: string;
    client_message_id: string;
    body: string;
  };

function record(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
function keys(value: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(value).sort().join(",") === expected.sort().join(",");
}
export function isTimestamp(value: unknown): value is string {
  // Preserve PostgreSQL microseconds rather than round-tripping through JS Date.
  return typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/
      .test(value) &&
    Number.isFinite(Date.parse(value));
}
function cursor(value: unknown): Cursor | undefined {
  if (
    !record(value) || !keys(value, ["time", "id"]) ||
    !isTimestamp(value.time) || !isUUID(value.id)
  ) return;
  return { time: value.time, id: value.id.toLowerCase() };
}
export function parseCommand(value: unknown): Command | undefined {
  if (!record(value)) return;
  if (value.action === "list" || value.action === "history") {
    const expected = value.action === "list"
      ? ["action"]
      : ["action", "conversation_id"];
    if (value.action === "history" && !isUUID(value.conversation_id)) return;
    let before: Cursor | undefined;
    if ("cursor" in value) {
      expected.push("cursor");
      before = cursor(value.cursor);
      if (!before) return;
    }
    if (!keys(value, expected)) return;
    return value.action === "list" ? { action: "list", cursor: before } : {
      action: "history",
      conversation_id: String(value.conversation_id).toLowerCase(),
      cursor: before,
    };
  }
  if (
    value.action === "open" && keys(value, ["action", "target_id"]) &&
    isUUID(value.target_id)
  ) {
    return { action: "open", target_id: value.target_id.toLowerCase() };
  }
  if (
    value.action === "send" &&
    keys(value, ["action", "conversation_id", "client_message_id", "body"]) &&
    isUUID(value.conversation_id) && isUUID(value.client_message_id) &&
    typeof value.body === "string" &&
    value.body.trim().length > 0 && !value.body.includes("\0") &&
    Array.from(value.body).length <= 2000
  ) {
    return {
      action: "send",
      conversation_id: value.conversation_id.toLowerCase(),
      client_message_id: value.client_message_id.toLowerCase(),
      body: value.body,
    };
  }
}
