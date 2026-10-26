import { createDiscoveryHandler } from "./handler.ts";
const person = "00000000-0000-0000-0000-000000000021";
const target = "00000000-0000-0000-0000-000000000022";
const config = {
  projectURL: "https://project.supabase.co",
  publicKey: "public",
  adminKey: "secret",
};
const profile = {
  id: target,
  first_name: "Alex",
  job_title: "Designer",
  goal: "Find a hiking buddy",
  city: "Scottsdale",
  date_of_birth: "1990-01-01",
};
function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const request = (body: unknown, token = "Bearer token") =>
  new Request("https://app/discovery", {
    method: "POST",
    headers: token ? { Authorization: token } : {},
    body: JSON.stringify(body),
  });

const mockFetch = (
  respond: (input: RequestInfo | URL, options?: RequestInit) => Response,
): typeof fetch =>
  ((input, options) =>
    Promise.resolve(respond(input, options))) as typeof fetch;

Deno.test("discovery rejects missing and invalid authentication before any admin call", async () => {
  let calls = 0;
  const handler = createDiscoveryHandler(
    config,
    (() => {
      calls++;
      return Promise.resolve(new Response(null, { status: 401 }));
    }) as typeof fetch,
  );
  assert((await handler(request({ action: "feed" }, ""))).status === 401);
  assert(calls === 0);
  assert((await handler(request({ action: "feed" }))).status === 401);
  assert(Number(calls) === 1);
});
Deno.test("discovery rejects caller impersonation, paths, and invalid choices", async () => {
  const handler = createDiscoveryHandler(
    config,
    (() => Promise.resolve(Response.json({ id: person }))) as typeof fetch,
  );
  for (
    const body of [
      { action: "feed", person: target },
      { action: "feed", path: "selfie.jpg" },
      { action: "decide", target_id: target, choice: "approve" },
      { action: "block", target_id: "../selfie.jpg" },
    ]
  ) assert((await handler(request(body))).status === 400);
});
Deno.test("feed projects public fields and signs profile-only paths for sixty seconds", async () => {
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input, options) => {
      const url = String(input);
      const body = options?.body ? JSON.parse(String(options.body)) : {};
      calls.push({ url, body });
      if (url.endsWith("/user")) return Response.json({ id: person });
      if (url.endsWith("/rpc/pilot_profile_photo_paths")) {
        return Response.json([`${target}/profile.jpg`]);
      }
      if (url.includes("/rpc/")) {
        return Response.json({
          state: "ready",
          visible: true,
          candidates: [profile],
          matches: [],
        });
      }
      return Response.json([{
        path: `${target}/profile.jpg`,
        signedURL:
          `/object/sign/private-photos/${target}/profile.jpg?token=short`,
      }]);
    }),
  );
  const response = await handler(request({ action: "feed" }));
  assert(response.status === 200);
  const feed = await response.json();
  assert(feed.candidates[0].date_of_birth === undefined);
  assert(feed.candidates[0].photo_url.startsWith(config.projectURL));
  assert(calls[1].body.person === person);
  assert(calls[3].body.expiresIn === 60);
  assert(
    JSON.stringify(calls[3].body.paths) ===
      JSON.stringify([`${target}/profile.jpg`]),
  );
  assert(response.headers.get("Cache-Control") === "no-store");
});
Deno.test("decision supplies verified caller and returns conflict without exposing upstream secrets", async () => {
  let body: Record<string, unknown> = {};
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input, options) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
      body = JSON.parse(String(options?.body));
      return new Response("secret upstream detail", { status: 400 });
    }),
  );
  const response = await handler(
    request({ action: "decide", target_id: target, choice: "connect" }),
  );
  assert(response.status === 409);
  assert(body.person === person && body.target === target);
  assert(!(await response.text()).includes("secret"));
});
Deno.test("restricted feeds never sign photos and malformed eligible feeds fail closed", async () => {
  for (const candidates of [[], [profile]]) {
    let calls = 0;
    const handler = createDiscoveryHandler(
      config,
      mockFetch(() => {
        calls++;
        if (calls === 1) return Response.json({ id: person });
        return Response.json({
          state: "restricted",
          visible: true,
          candidates,
          matches: [],
        });
      }),
    );
    assert(
      (await handler(request({ action: "feed" }))).status ===
        (candidates.length ? 503 : 200),
    );
    assert(calls === 2);
  }
});
Deno.test("signing failures and unexpected URL paths fail without leaking data", async () => {
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
      if (String(input).endsWith("/rpc/pilot_profile_photo_paths")) {
        return Response.json([`${target}/profile.jpg`]);
      }
      if (String(input).includes("/rpc/")) {
        return Response.json({
          state: "ready",
          visible: true,
          candidates: [profile],
          matches: [],
        });
      }
      return Response.json([{
        path: `${target}/profile.jpg`,
        signedURL: `/object/sign/private-photos/${target}/selfie.jpg?token=bad`,
      }]);
    }),
  );
  assert((await handler(request({ action: "feed" }))).status === 503);
});
Deno.test("visibility and blocking use only the verified caller", async () => {
  for (
    const command of [{ action: "visibility", enabled: false }, {
      action: "block",
      target_id: target,
    }]
  ) {
    let mutation: Record<string, unknown> = {};
    const handler = createDiscoveryHandler(
      config,
      mockFetch((input, options) => {
        if (String(input).endsWith("/user")) {
          return Response.json({ id: person });
        }
        if (!String(input).endsWith("pilot_discovery_feed")) {
          mutation = JSON.parse(String(options?.body));
          return Response.json(null);
        }
        return Response.json({
          state: "hidden",
          visible: false,
          candidates: [],
          matches: [],
        });
      }),
    );
    assert((await handler(request(command))).status === 200);
    assert(mutation.person === person);
  }
});

Deno.test("preferences save binds the caller and projects only the age range", async () => {
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input, options) => {
      const url = String(input);
      if (url.endsWith("/user")) return Response.json({ id: person });
      calls.push({ url, body: JSON.parse(String(options?.body)) });
      return Response.json({
        minimum_age: 25,
        maximum_age: null,
        date_of_birth: "private",
      });
    }),
  );
  const response = await handler(
    request({ action: "save_preferences", minimum_age: 25, maximum_age: null }),
  );
  assert(response.status === 200);
  const result = await response.json();
  assert(
    JSON.stringify(result) ===
      JSON.stringify({ minimum_age: 25, maximum_age: null }),
  );
  assert(
    calls.length === 1 &&
      calls[0].url.endsWith("/rpc/pilot_discovery_save_preferences"),
  );
  assert(calls[0].body.person === person && calls[0].body.maximum_age === null);
  assert(response.headers.get("Cache-Control") === "no-store");
});

Deno.test("preferences reject invalid bounds, extra identities and fractional ages before RPC", async () => {
  let rpcCalls = 0;
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
      rpcCalls++;
      return Response.json({});
    }),
  );
  for (
    const body of [
      { action: "preferences", person: target },
      { action: "save_preferences", minimum_age: 17, maximum_age: null },
      { action: "save_preferences", minimum_age: 30, maximum_age: 29 },
      { action: "save_preferences", minimum_age: 18.5, maximum_age: 50 },
      {
        action: "save_preferences",
        minimum_age: 18,
        maximum_age: null,
        user_id: target,
      },
      { action: "save_preferences", minimum_age: 18 },
      {
        action: "save_preferences",
        minimum_age: 2147483648,
        maximum_age: null,
      },
    ]
  ) assert((await handler(request(body))).status === 400);
  assert(rpcCalls === 0);
});

Deno.test("preferences read returns defaults and rejects an invalid upstream range", async () => {
  let invalid = false;
  const handler = createDiscoveryHandler(
    config,
    mockFetch((input) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
      return Response.json(
        invalid
          ? { minimum_age: 50, maximum_age: 20 }
          : { minimum_age: 18, maximum_age: null },
      );
    }),
  );
  const response = await handler(request({ action: "preferences" }));
  assert(response.status === 200 && (await response.json()).minimum_age === 18);
  invalid = true;
  const failed = await handler(request({ action: "preferences" }));
  assert(failed.status === 503 && !(await failed.text()).includes("50"));
});
