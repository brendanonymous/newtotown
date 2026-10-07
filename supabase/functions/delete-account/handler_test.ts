import { createDeleteAccountHandler } from "./handler.ts";

const ownerID = "35be4c9b-1a76-4207-a6b1-93703d093dd1";
const otherID = "35be4c9b-1a76-4207-a6b1-93703d093dd2";
const configuration = {
  projectURL: "https://example.supabase.co",
  publicKey: "public-test-key",
  adminKey: "server-only-test-key",
};

function expect(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function request(body?: string): Request {
  return new Request("https://example.test/delete-account", {
    method: "POST",
    headers: { Authorization: "Bearer caller-token" },
    body,
  });
}

// Requests are inspected at the HTTP boundary, including credential separation.
function backend(statuses: number[] = [200, 204, 200]) {
  const calls: { url: string; method: string; headers: Headers }[] = [];
  const send: typeof fetch = (input, init) => {
    calls.push({
      url: String(input),
      method: init?.method ?? "GET",
      headers: new Headers(init?.headers),
    });
    const status = statuses[calls.length - 1];
    if (!status) throw new Error("Unexpected backend request");
    return Promise.resolve(
      new Response(
        status === 204
          ? null
          : JSON.stringify({ id: ownerID, error: "private upstream detail" }),
        { status },
      ),
    );
  };
  return { calls, handler: createDeleteAccountHandler(configuration, send) };
}

Deno.test("missing credentials and unsupported methods cannot reach Auth", async () => {
  const { calls, handler } = backend();
  expect(
    (await handler(new Request("https://example.test", { method: "POST" })))
      .status === 401,
    "Missing token accepted",
  );
  expect(
    (await handler(new Request("https://example.test"))).status === 405,
    "GET accepted",
  );
  expect(calls.length === 0, "Unauthenticated caller reached backend");
});

Deno.test("invalid or deleted caller cannot revoke sessions or delete anyone", async () => {
  const { calls, handler } = backend([401]);
  expect((await handler(request())).status === 401, "Invalid token accepted");
  expect(calls.length === 1, "Deletion ran after failed identity check");
});

Deno.test("body cannot select another account; verified owner is revoked then hard deleted", async () => {
  const { calls, handler } = backend();
  expect(
    (await handler(request(JSON.stringify({ user_id: otherID })))).status ===
      204,
    "Deletion failed",
  );
  expect(
    calls.length === 3,
    "Missing identity, revocation, or deletion request",
  );
  expect(calls[0].url.endsWith("/user"), "Identity was not checked first");
  expect(
    calls[0].headers.get("apikey") === configuration.publicKey,
    "Admin key used for identity lookup",
  );
  expect(
    calls[1].url.endsWith("/logout?scope=global"),
    "All sessions were not revoked",
  );
  expect(
    calls[1].headers.get("Authorization") === "Bearer caller-token",
    "Wrong session revoked",
  );
  expect(
    calls[2].url.endsWith(`/admin/users/${ownerID}`),
    "Unverified account selected",
  );
  expect(calls[2].method === "DELETE", "Not an Auth hard deletion");
  expect(
    calls[2].headers.get("Authorization") ===
      `Bearer ${configuration.adminKey}`,
    "Missing server authorization",
  );
});

Deno.test("failed session revocation stops deletion", async () => {
  const { calls, handler } = backend([200, 500]);
  expect(
    (await handler(request())).status === 503,
    "Failure reported as success",
  );
  expect(calls.length === 2, "Account deleted before sessions revoked");
});

Deno.test("failed Auth deletion is retryable and never exposes upstream details", async () => {
  const { handler } = backend([200, 204, 500]);
  const response = await handler(request());
  expect(response.status === 503, "Deletion failure reported as success");
  const body = await response.text();
  expect(
    !body.includes("private upstream detail") &&
      !body.includes(configuration.adminKey),
    "Sensitive error leaked",
  );
});

Deno.test("network failure produces a controlled error", async () => {
  const handler = createDeleteAccountHandler(
    configuration,
    () => Promise.reject(new Error("secret")),
  );
  expect(
    (await handler(request())).status === 503,
    "Network error escaped handler",
  );
});
