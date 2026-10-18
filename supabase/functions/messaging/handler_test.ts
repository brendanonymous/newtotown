import { createMessagingHandler } from "./handler.ts";

const caller = "00000000-0000-0000-0000-000000000041";
const peer = "00000000-0000-0000-0000-000000000042";
const threadID = "00000000-0000-0000-0000-000000000051";
const retryID = "00000000-0000-0000-0000-000000000061";
const time = "2026-10-17T23:00:00.123456+00:00";
const config = {
  projectURL: "https://project.supabase.co",
  publicKey: "public-key",
  adminKey: "server-key",
};
const message = {
  id: retryID,
  conversation_id: threadID,
  sender_id: caller,
  client_message_id: retryID,
  body: "Coffee on Saturday?",
  created_at: time,
};
const conversation = {
  id: threadID,
  created_at: time,
  last_activity_at: time,
  last_message: message,
  participant: {
    id: peer,
    first_name: "Alex",
    job_title: "Designer",
    goal: "Find a hiking buddy.",
    city: "Scottsdale",
    date_of_birth: "1990-01-01",
    selfie: "private",
  },
  private_field: "must-not-leak",
};
const sendCommand = {
  action: "send",
  conversation_id: threadID,
  client_message_id: retryID,
  body: message.body,
};
function assert(value: unknown, reason = "Assertion failed"): asserts value {
  if (!value) throw new Error(reason);
}
function request(value: unknown, authorization = "Bearer token") {
  return new Request("https://app/messaging", {
    method: "POST",
    headers: { Authorization: authorization },
    body: JSON.stringify(value),
  });
}
function backend(result: unknown, rpcStatus = 200) {
  const calls: {
    url: string;
    headers: Headers;
    body: Record<string, unknown>;
  }[] = [];
  const handler = createMessagingHandler(
    config,
    ((input, init) => {
      const url = String(input);
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      calls.push({ url, headers: new Headers(init?.headers), body });
      if (url.endsWith("/auth/v1/user")) {
        return Promise.resolve(Response.json({ id: caller }));
      }
      if (url.includes("/rpc/")) {
        return Promise.resolve(Response.json(result, { status: rpcStatus }));
      }
      if (url.endsWith("/storage/v1/object/sign/private-photos")) {
        assert(Array.isArray(body.paths));
        return Promise.resolve(Response.json(
          body.paths.map((path: string) => ({
            path,
            signedURL: `/object/sign/private-photos/${path}?token=signed`,
          })),
        ));
      }
      throw new Error("Unexpected request");
    }) as typeof fetch,
  );
  return { handler, calls };
}
Deno.test("messaging verifies identity with the public key and injects the only sender", async () => {
  const { handler, calls } = backend({
    ...message,
    secret_field: "do-not-leak",
  });
  const response = await handler(request(sendCommand));
  assert(response.status === 200);
  assert(response.headers.get("Cache-Control") === "no-store");
  assert(calls.length === 2, "Send should not sign photos");
  assert(calls[0].headers.get("apikey") === config.publicKey);
  assert(calls[0].headers.get("Authorization") === "Bearer token");
  assert(calls[1].headers.get("Authorization") === `Bearer ${config.adminKey}`);
  assert(calls[1].url.endsWith("/pilot_messaging_send"));
  assert(calls[1].body.person === caller && calls[1].body.retry_id === retryID);
  const sent = await response.json();
  assert(sent.body === message.body && !sent.secret_field);
});
Deno.test("inbox, open, and history explicitly project fields and sign only authorized profile photos", async () => {
  for (
    const [command, result] of [
      [{ action: "list" }, {
        conversations: [conversation],
        next_cursor: null,
        secret: "hidden",
      }],
      [{ action: "open", target_id: peer }, conversation],
      [{ action: "history", conversation_id: threadID }, {
        conversation,
        messages: [message],
        next_cursor: null,
        secret: "hidden",
      }],
    ]
  ) {
    const { handler, calls } = backend(result);
    const response = await handler(request(command));
    assert(response.status === 200);
    const text = await response.text();
    assert(
      !text.includes("date_of_birth") && !text.includes("selfie") &&
        !text.includes("private_field") && !text.includes('"secret"'),
    );
    assert(text.includes("photo_url"));
    assert(
      JSON.stringify(calls[2].body.paths) ===
        JSON.stringify([`${peer}/profile.jpg`]),
    );
    assert(calls[2].body.expiresIn === 60);
  }
});
Deno.test("empty inbox avoids signing and cursor microseconds are preserved", async () => {
  const { handler, calls } = backend({ conversations: [], next_cursor: null });
  const response = await handler(
    request({ action: "list", cursor: { time, id: threadID } }),
  );
  assert(response.status === 200 && calls.length === 2);
  assert(
    calls[1].body.before_time === time && calls[1].body.before_id === threadID,
  );
});
Deno.test("messaging rejects forged identities, timestamps, paths, and malformed commands before RPC", async () => {
  const { handler, calls } = backend({});
  const commands = [
    null,
    [],
    {},
    { action: "list", person: peer },
    { ...sendCommand, sender_id: peer },
    { ...sendCommand, created_at: time },
    { ...sendCommand, body: "\u00a0\ufeff\n" },
    { ...sendCommand, body: "x".repeat(2001) },
    { ...sendCommand, body: "\0" },
    { ...sendCommand, conversation_id: "../path" },
    { action: "list", cursor: { time: "not-a-date", id: threadID } },
    { action: "list", cursor: { time, id: threadID, person: peer } },
    { action: "list", cursor: null },
    { action: "open", target_id: caller, path: "selfie.jpg" },
  ];
  for (const command of commands) {
    assert((await handler(request(command))).status === 400);
  }
  assert(
    calls.every((call) => call.url.endsWith("/user")),
    "Invalid command reached RPC",
  );
});
Deno.test("message limit counts Unicode code points and preserves authored whitespace", async () => {
  const body = "😀".repeat(2000);
  for (const text of [body, "  Line one\nLine two  "]) {
    const { handler, calls } = backend({ ...message, body: text });
    assert(
      (await handler(request({ ...sendCommand, body: text }))).status === 200,
    );
    assert(calls[1].body.content === text);
  }
});
Deno.test("oversized and malformed streaming bodies are bounded before RPC", async () => {
  const { handler, calls } = backend({});
  for (const body of ["{", "x".repeat(32_769)]) {
    assert(
      (await handler(
        new Request("https://app/messaging", {
          method: "POST",
          headers: { Authorization: "Bearer token" },
          body,
        }),
      )).status === 400,
    );
  }
  assert(calls.length === 2);
});
Deno.test("expected RPC failures map to sanitized unavailable, conflict, and input responses", async () => {
  for (
    const [code, status] of [["P0001", 404], ["P0002", 409], ["22023", 400], [
      "22007",
      400,
    ], ["23503", 503]]
  ) {
    const { handler } = backend({
      code,
      message: "private SQL detail server-key",
    }, 400);
    const response = await handler(request(sendCommand));
    assert(response.status === status);
    assert(!(await response.text()).includes("private SQL"));
  }
});
Deno.test("malformed or cross-conversation responses fail closed", async () => {
  for (
    const result of [
      { ...message, sender_id: peer },
      { ...message, conversation_id: peer },
      { ...message, body: "Changed" },
      { ...message, client_message_id: peer },
      null,
    ]
  ) {
    const { handler } = backend(result);
    assert((await handler(request(sendCommand))).status === 503);
  }
  const { handler } = backend({
    conversation,
    messages: [{ ...message, conversation_id: peer }],
    next_cursor: null,
  });
  assert(
    (await handler(request({ action: "history", conversation_id: threadID })))
      .status === 503,
  );
});
Deno.test("over-limit and malformed pages cannot be exposed", async () => {
  for (
    const result of [
      { conversations: Array(51).fill(conversation), next_cursor: null },
      { conversations: [conversation], next_cursor: { time, id: "invalid" } },
      {
        conversations: [{ ...conversation, participant: null }],
        next_cursor: null,
      },
    ]
  ) {
    const { handler } = backend(result);
    assert((await handler(request({ action: "list" }))).status === 503);
  }
});
Deno.test("unsupported methods, missing Auth, and Auth network failures are safe", async () => {
  let calls = 0;
  const handler = createMessagingHandler(
    config,
    (() => {
      calls++;
      throw new Error("secret network detail");
    }) as typeof fetch,
  );
  assert((await handler(new Request("https://app/messaging"))).status === 405);
  assert((await handler(request(sendCommand, ""))).status === 401);
  assert(calls === 0);
  const response = await handler(request(sendCommand));
  assert(
    response.status === 503 && !(await response.text()).includes("secret"),
  );
});
