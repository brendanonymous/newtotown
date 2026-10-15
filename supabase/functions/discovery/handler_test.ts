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
    (async (input, options) => {
      const url = String(input);
      const body = options?.body ? JSON.parse(String(options.body)) : {};
      calls.push({ url, body });
      if (url.endsWith("/user")) return Response.json({ id: person });
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
    }) as typeof fetch,
  );
  const response = await handler(request({ action: "feed" }));
  assert(response.status === 200);
  const feed = await response.json();
  assert(feed.candidates[0].date_of_birth === undefined);
  assert(feed.candidates[0].photo_url.startsWith(config.projectURL));
  assert(calls[1].body.person === person);
  assert(calls[2].body.expiresIn === 60);
  assert(
    JSON.stringify(calls[2].body.paths) ===
      JSON.stringify([`${target}/profile.jpg`]),
  );
  assert(response.headers.get("Cache-Control") === "no-store");
});
Deno.test("decision supplies verified caller and returns conflict without exposing upstream secrets", async () => {
  let body: Record<string, unknown> = {};
  const handler = createDiscoveryHandler(
    config,
    (async (input, options) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
      body = JSON.parse(String(options?.body));
      return new Response("secret upstream detail", { status: 400 });
    }) as typeof fetch,
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
      (async () => {
        calls++;
        if (calls === 1) return Response.json({ id: person });
        return Response.json({
          state: "restricted",
          visible: true,
          candidates,
          matches: [],
        });
      }) as typeof fetch,
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
    (async (input) => {
      if (String(input).endsWith("/user")) return Response.json({ id: person });
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
    }) as typeof fetch,
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
      (async (input, options) => {
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
      }) as typeof fetch,
    );
    assert((await handler(request(command))).status === 200);
    assert(mutation.person === person);
  }
});
