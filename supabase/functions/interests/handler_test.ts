import { createInterestsHandler } from "./handler.ts";
import { readCards } from "../_shared/profile-photos.ts";

const caller = "00000000-0000-0000-0000-000000000041";
const config = {
  projectURL: "https://project.supabase.co",
  publicKey: "public",
  adminKey: "secret",
};
const snapshot = {
  categories: [
    "sports_fitness",
    "outdoors",
    "food_drinks",
    "arts_entertainment",
    "social_hobbies",
  ].map((id) => ({
    id,
    title: id,
    options: [1, 2, 3, 4].map((n) => ({
      id: `${id}_${n}`,
      title: `Choice ${n}`,
      private: "hidden",
    })),
  })),
  profile_option_ids: ["sports_fitness_1"],
  filter_option_ids: [],
  private: "hidden",
};
const request = (value: unknown) =>
  new Request("https://app/interests", {
    method: "POST",
    headers: { Authorization: "Bearer member" },
    body: JSON.stringify(value),
  });
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
function backend(result: unknown = snapshot, status = 200, authStatus = 200) {
  const calls: {
    url: string;
    body: Record<string, unknown>;
    headers: Headers;
  }[] = [];
  const handler = createInterestsHandler(
    config,
    ((url, init) => {
      calls.push({
        url: String(url),
        body: init?.body ? JSON.parse(String(init.body)) : {},
        headers: new Headers(init?.headers),
      });
      return Promise.resolve(
        String(url).endsWith("/auth/v1/user")
          ? Response.json(authStatus === 200 ? { id: caller } : {}, {
            status: authStatus,
          })
          : Response.json(result, { status }),
      );
    }) as typeof fetch,
  );
  return { handler, calls };
}
Deno.test("interests resolves live owner and returns only catalog and own selections", async () => {
  const { handler, calls } = backend();
  const response = await handler(request({ action: "load" }));
  assert(
    response.status === 200 &&
      response.headers.get("Cache-Control") === "no-store",
  );
  const body = await response.json();
  assert(
    body.categories.length === 5 &&
      body.profile_option_ids[0] === "sports_fitness_1",
  );
  assert(!JSON.stringify(body).includes("hidden"));
  assert(
    calls.length === 2 &&
      calls[0].headers.get("Authorization") === "Bearer member",
  );
  assert(calls[1].headers.get("Authorization") === "Bearer secret");
  assert(JSON.stringify(calls[1].body) === JSON.stringify({ person: caller }));
});
Deno.test("interests keeps profile and filter commands separate and accepts empty clearing", async () => {
  for (const selection_kind of ["profile", "filters"]) {
    const { handler, calls } = backend();
    assert(
      (await handler(
        request({ action: "save", selection_kind, option_ids: [] }),
      )).status === 200,
    );
    assert(calls[1].url.endsWith("/pilot_interests_save"));
    assert(
      calls[1].body.person === caller &&
        calls[1].body.selection_kind === selection_kind,
    );
    assert(JSON.stringify(calls[1].body.option_ids) === "[]");
  }
});
Deno.test("interests rejects forged owners, duplicate/invalid IDs and malformed or oversized bodies", async () => {
  for (
    const body of [
      { action: "load", person: caller },
      { action: "save", selection_kind: "profile", option_ids: ["a", "a"] },
      { action: "save", selection_kind: "profile", option_ids: [null] },
      { action: "save", selection_kind: "profile", option_ids: ["Golf"] },
      {
        action: "save",
        selection_kind: "profile",
        option_ids: Array.from({ length: 16 }, (_, i) => `option_${i}`),
      },
      { action: "save", selection_kind: "all", option_ids: [] },
      {
        action: "save",
        selection_kind: "profile",
        option_ids: [],
        target_id: caller,
      },
      { action: "load", padding: "x".repeat(5000) },
      [],
      null,
    ]
  ) {
    const { handler, calls } = backend();
    assert((await handler(request(body))).status === 400 && calls.length === 1);
  }
  const { handler, calls } = backend();
  assert(
    (await handler(
      new Request("https://app", {
        method: "POST",
        headers: { Authorization: "Bearer member" },
        body: "{",
      }),
    )).status === 400,
  );
  assert(calls.length === 1);
});
Deno.test("interests rejects missing, expired and malformed Auth identities before RPC", async () => {
  const { handler, calls } = backend();
  assert(
    (await handler(new Request("https://app", { method: "POST" }))).status ===
        401 && calls.length === 0,
  );
  const expired = backend(snapshot, 200, 401);
  assert(
    (await expired.handler(request({ action: "load" }))).status === 401 &&
      expired.calls.length === 1,
  );
  assert((await handler(new Request("https://app"))).status === 405);
});
Deno.test("interests maps validation and missing profiles without exposing upstream errors", async () => {
  for (
    const [code, status] of [["22023", 400], ["P0001", 404], [
      "XX000",
      503,
    ]] as const
  ) {
    const { handler } = backend(
      { code, message: "secret database error" },
      400,
    );
    const response = await handler(
      request({ action: "save", selection_kind: "profile", option_ids: [] }),
    );
    assert(
      response.status === status && !(await response.text()).includes("secret"),
    );
  }
});
Deno.test("interests rejects invalid server projections rather than leaking private data", async () => {
  for (
    const result of [
      { ...snapshot, profile_option_ids: ["unknown"] },
      {
        ...snapshot,
        profile_option_ids: ["sports_fitness_1", "sports_fitness_1"],
      },
      {
        ...snapshot,
        profile_option_ids: [1, 2, 3, 4].map((n) => `sports_fitness_${n}`),
      },
      { ...snapshot, categories: [] },
    ]
  ) {
    assert(
      (await backend(result).handler(request({ action: "load" }))).status ===
        503,
    );
  }
});
Deno.test("public cards project interests, never private filters, and support older responses", () => {
  const card = {
    id: caller,
    first_name: "Alex",
    job_title: "Designer",
    goal: "Coffee",
    city: "Scottsdale",
  };
  const [old] = readCards([card], 1);
  assert(old.interests === undefined);
  const [current] = readCards([{
    ...card,
    interests: [{
      id: "golf",
      category_id: "sports_fitness",
      title: "Golf",
      private: "hidden",
    }],
    filter_option_ids: ["coffee"],
  }], 1);
  assert(
    current.interests?.[0].id === "golf" &&
      !JSON.stringify(current).includes("hidden") &&
      !JSON.stringify(current).includes("coffee"),
  );
  for (
    const interests of [[{
      id: "golf",
      category_id: "sports_fitness",
      title: "Golf",
    }, { id: "golf", category_id: "sports_fitness", title: "Golf" }], "golf"]
  ) {
    let rejected = false;
    try {
      readCards([{ ...card, interests }], 1);
    } catch {
      rejected = true;
    }
    assert(rejected);
  }
});
