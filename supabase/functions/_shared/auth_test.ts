import { authenticate } from "./auth.ts";
import { readJSON } from "./http.ts";

function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
const config = {
  projectURL: "https://project.supabase.co",
  publicKey: "public",
};
const request = new Request("https://app", {
  headers: { Authorization: "Bearer caller" },
});
Deno.test("shared Auth rejects revoked/deleted users, outages, and malformed identities", async () => {
  for (
    const [status, body, expected] of [
      [401, {}, 401],
      [403, {}, 401],
      [500, {}, 503],
      [200, { id: "invalid" }, 503],
      [200, null, 503],
    ] as const
  ) {
    const result = await authenticate(
      request,
      config,
      (() => Promise.resolve(Response.json(body, { status }))) as typeof fetch,
    );
    assert(result instanceof Response && result.status === expected);
    assert(result.headers.get("Cache-Control") === "no-store");
  }
});
Deno.test("body limit is enforced across streamed chunks and cancels further input", async () => {
  let cancelled = false;
  let pulls = 0;
  const stream = new ReadableStream({
    pull(controller) {
      pulls++;
      controller.enqueue(new Uint8Array(10));
    },
    cancel() {
      cancelled = true;
    },
  });
  const incoming = new Request("https://app", { method: "POST", body: stream });
  let rejected = false;
  try {
    await readJSON(incoming, 15);
  } catch {
    rejected = true;
  }
  assert(rejected && cancelled && pulls <= 3);
});
