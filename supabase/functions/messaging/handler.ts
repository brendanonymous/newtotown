import { type AuthConfiguration, authenticate } from "../_shared/auth.ts";
import { jsonReply, readJSON } from "../_shared/http.ts";
import { signProfilePhotos } from "../_shared/profile-photos.ts";
import { parseCommand } from "./commands.ts";
import {
  conversation,
  conversationPage,
  historyPage,
  message,
  withPhotoURLs,
} from "./projection.ts";

type Configuration = AuthConfiguration & { adminKey: string };

export function createMessagingHandler(
  config: Configuration,
  send: typeof fetch = fetch,
) {
  const adminHeaders = {
    apikey: config.adminKey,
    Authorization: `Bearer ${config.adminKey}`,
    "Content-Type": "application/json",
  };
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonReply(405, { error: "Method not allowed" });
    }
    try {
      const identity = await authenticate(request, config, send);
      if (identity instanceof Response) return identity;
      let command;
      try {
        command = parseCommand(await readJSON(request, 32_768));
      } catch { /* Invalid or oversized body. */ }
      if (!command) {
        return jsonReply(400, { error: "Invalid messaging request" });
      }
      const person = identity.userID;
      let rpcName: string;
      let rpcArguments: Record<string, unknown>;
      switch (command.action) {
        case "list":
          rpcName = "pilot_messaging_list";
          rpcArguments = {
            person,
            before_time: command.cursor?.time ?? null,
            before_id: command.cursor?.id ?? null,
          };
          break;
        case "open":
          rpcName = "pilot_messaging_open";
          rpcArguments = { person, target: command.target_id };
          break;
        case "history":
          rpcName = "pilot_messaging_history";
          rpcArguments = {
            person,
            thread: command.conversation_id,
            before_time: command.cursor?.time ?? null,
            before_id: command.cursor?.id ?? null,
          };
          break;
        case "send":
          rpcName = "pilot_messaging_send";
          rpcArguments = {
            person,
            thread: command.conversation_id,
            retry_id: command.client_message_id,
            content: command.body,
          };
          break;
      }
      const response = await send(
        `${config.projectURL}/rest/v1/rpc/${rpcName}`,
        {
          method: "POST",
          headers: adminHeaders,
          body: JSON.stringify(rpcArguments),
          signal: AbortSignal.timeout(15_000),
        },
      );
      if (!response.ok) {
        const failure = await response.json();
        if (failure?.code === "P0001") {
          return jsonReply(404, { error: "Conversation unavailable" });
        }
        if (failure?.code === "P0002") {
          return jsonReply(409, { error: "Message retry conflict" });
        }
        if (["22023", "22007", "22008"].includes(failure?.code)) {
          return jsonReply(400, { error: "Invalid messaging request" });
        }
        throw new Error("Messaging request failed");
      }
      const raw = await response.json();
      const attachPhotos = (threads: ReturnType<typeof conversation>[]) =>
        withPhotoURLs(
          threads,
          (profiles) =>
            signProfilePhotos(profiles, config.projectURL, adminHeaders, send),
        );
      switch (command.action) {
        case "list": {
          const result = conversationPage(raw, person);
          return jsonReply(200, {
            ...result,
            conversations: await attachPhotos(result.conversations),
          });
        }
        case "open": {
          const result = conversation(raw, person);
          if (result.participant.id !== command.target_id) {
            throw new Error("Unexpected peer");
          }
          return jsonReply(200, (await attachPhotos([result]))[0]);
        }
        case "history": {
          const result = historyPage(raw, person, command.conversation_id);
          return jsonReply(200, {
            ...result,
            conversation: (await attachPhotos([result.conversation]))[0],
          });
        }
        case "send": {
          const sent = message(raw, command.conversation_id);
          if (
            sent.sender_id !== person ||
            sent.client_message_id !== command.client_message_id ||
            sent.body !== command.body
          ) {
            throw new Error("Unexpected send result");
          }
          return jsonReply(200, sent);
        }
      }
    } catch {
      return jsonReply(503, {
        error: "Messaging unavailable. Please try again.",
      });
    }
  };
}
