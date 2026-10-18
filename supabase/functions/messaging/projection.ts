import { isUUID } from "../_shared/auth.ts";
import { type Card, readCards } from "../_shared/profile-photos.ts";
import { isTimestamp } from "./commands.ts";

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid response");
  }
  return value as Record<string, unknown>;
}
export function message(value: unknown, thread: string) {
  const item = object(value);
  if (
    !isUUID(item.id) || !isUUID(item.conversation_id) ||
    !isUUID(item.sender_id) ||
    !isUUID(item.client_message_id) || !isTimestamp(item.created_at) ||
    typeof item.body !== "string" || !item.body.trim() ||
    Array.from(item.body).length > 2000 ||
    item.conversation_id !== thread
  ) throw new Error("Invalid message");
  return {
    id: item.id,
    conversation_id: item.conversation_id,
    sender_id: item.sender_id,
    client_message_id: item.client_message_id,
    body: item.body,
    created_at: item.created_at,
  };
}
export function conversation(value: unknown, caller: string) {
  const item = object(value);
  if (
    !isUUID(item.id) || !isTimestamp(item.created_at) ||
    !isTimestamp(item.last_activity_at)
  ) {
    throw new Error("Invalid conversation");
  }
  const participant = readCards([item.participant], 1)[0];
  if (participant.id === caller) throw new Error("Invalid participant");
  const last = item.last_message === null
    ? null
    : message(item.last_message, item.id);
  if (last && ![caller, participant.id].includes(last.sender_id)) {
    throw new Error("Invalid sender");
  }
  return {
    id: item.id,
    created_at: item.created_at,
    last_activity_at: item.last_activity_at,
    participant,
    last_message: last,
  };
}
function pageCursor(
  item: Record<string, unknown>,
): { time: string; id: string } | null {
  if (item.next_cursor === null) return null;
  const cursor = object(item.next_cursor);
  if (!isTimestamp(cursor.time) || !isUUID(cursor.id)) {
    throw new Error("Invalid cursor");
  }
  return { time: cursor.time, id: cursor.id };
}

export function conversationPage(value: unknown, caller: string) {
  const item = object(value);
  if (!Array.isArray(item.conversations) || item.conversations.length > 50) {
    throw new Error("Invalid inbox");
  }
  return {
    conversations: item.conversations.map((value) =>
      conversation(value, caller)
    ),
    next_cursor: pageCursor(item),
  };
}

export function historyPage(value: unknown, caller: string, threadID: string) {
  const item = object(value);
  const thread = conversation(item.conversation, caller);
  if (
    thread.id !== threadID || !Array.isArray(item.messages) ||
    item.messages.length > 50
  ) {
    throw new Error("Invalid history");
  }
  const messages = item.messages.map((value) => message(value, thread.id));
  if (
    messages.some((value) =>
      ![caller, thread.participant.id].includes(value.sender_id)
    )
  ) {
    throw new Error("Invalid sender");
  }
  return { conversation: thread, messages, next_cursor: pageCursor(item) };
}

/** Only projected public peers reach the existing profile-only photo signer. */
export async function withPhotoURLs(
  threads: ReturnType<typeof conversation>[],
  sign: (profiles: Card[]) => Promise<Map<string, string>>,
) {
  const urls = await sign(threads.map((thread) => thread.participant));
  return threads.map((thread) => ({
    ...thread,
    participant: {
      ...thread.participant,
      photo_url: urls.get(`${thread.participant.id}/profile.jpg`),
    },
  }));
}
