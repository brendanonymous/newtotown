import { createReportsHandler } from "./handler.ts";

const caller = "00000000-0000-0000-0000-000000000041";
const peer = "00000000-0000-0000-0000-000000000042";
const retry = "00000000-0000-0000-0000-000000000061";
const receipt = "00000000-0000-0000-0000-000000000071";
const config = {
  projectURL: "https://project.supabase.co",
  publicKey: "public",
  adminKey: "secret",
};
const body = {
  target_id: peer,
  reason: "non_platonic",
  details: null,
  client_report_id: retry,
};
const request = (value: unknown) =>
  new Request("https://app/reports", {
    method: "POST",
    headers: { Authorization: "Bearer member" },
    body: JSON.stringify(value),
  });
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
function backend(
  result: unknown = { id: receipt, status: "pending", secret: "hidden" },
  status = 200,
) {
  const calls: {
    url: string;
    body: Record<string, unknown>;
    headers: Headers;
  }[] = [];
  const handler = createReportsHandler(
    config,
    ((url, init) => {
      calls.push({
        url: String(url),
        body: init?.body ? JSON.parse(String(init.body)) : {},
        headers: new Headers(init?.headers),
      });
      return Promise.resolve(
        String(url).endsWith("/auth/v1/user")
          ? Response.json({ id: caller })
          : Response.json(result, { status }),
      );
    }) as typeof fetch,
  );
  return { handler, calls };
}
Deno.test("reports injects only verified reporter and returns only receipt", async () => {
  const { handler, calls } = backend();
  const response = await handler(request(body));
  assert(
    response.status === 200 &&
      response.headers.get("Cache-Control") === "no-store",
  );
  assert(
    JSON.stringify(await response.json()) === JSON.stringify({ id: receipt }),
  );
  assert(calls.length === 2);
  assert(calls[0].headers.get("apikey") === config.publicKey);
  assert(calls[1].headers.get("Authorization") === "Bearer secret");
  assert(calls[1].url.endsWith("/pilot_report_profile"));
  assert(
    calls[1].body.person === caller && calls[1].body.target === peer &&
      calls[1].body.retry_id === retry,
  );
});
Deno.test("reports rejects impersonation, review fields, invalid reasons, and oversized details", async () => {
  for (
    const invalid of [
      { ...body, reporter_id: peer },
      { ...body, status: "reviewed" },
      { ...body, target_id: caller },
      { ...body, reason: "invalid" },
      { ...body, details: "😀".repeat(1001) },
      { ...body, details: "bad\0" },
      { ...body, client_report_id: "invalid" },
      { ...body, details: undefined },
      [],
      null,
    ]
  ) {
    const { handler, calls } = backend();
    assert((await handler(request(invalid))).status === 400);
    assert(calls.length === 1);
  }
  const { handler } = backend();
  assert(
    (await handler(request({ ...body, details: "😀".repeat(1000) }))).status ===
      200,
  );
});
Deno.test("reports bounds raw request bytes and rejects missing auth and wrong methods", async () => {
  const { handler, calls } = backend();
  assert(
    (await handler(
      new Request("https://app", {
        method: "POST",
        headers: { Authorization: "Bearer member" },
        body: " ".repeat(32769),
      }),
    )).status === 400,
  );
  assert(
    (await handler(
      new Request("https://app", {
        method: "POST",
        body: JSON.stringify(body),
      }),
    )).status === 401,
  );
  assert((await handler(new Request("https://app"))).status === 405);
  assert(calls.length === 1);
});
Deno.test("reports sanitizes unavailable, duplicate-payload conflict, and upstream failures", async () => {
  for (
    const [code, expected] of [["P0001", 404], ["23505", 409], ["22023", 400], [
      "XX000",
      503,
    ]] as const
  ) {
    const { handler } = backend({ code, message: "internal secret" }, 400);
    const response = await handler(request(body));
    assert(
      response.status === expected &&
        !(await response.text()).includes("secret"),
    );
  }
  const { handler } = backend({ id: "invalid", secret: "hidden" });
  assert((await handler(request(body))).status === 503);
});
Deno.test("reports never writes after live Auth revokes the session", async () => {
  let calls = 0;
  const handler = createReportsHandler(
    config,
    (() => {
      calls += 1;
      return Promise.resolve(
        Response.json({ error: "revoked" }, { status: 401 }),
      );
    }) as typeof fetch,
  );
  assert((await handler(request(body))).status === 401 && calls === 1);
});
