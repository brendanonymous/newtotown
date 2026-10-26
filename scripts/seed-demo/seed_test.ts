import { galleryFor, validateGallery } from "./gallery.ts";
import {
  assertTestDatabase,
  emailFor,
  ownedUser,
  seedTag,
  testProjectRef,
  validateProfiles,
} from "./model.ts";
import { SeedBackend, type SeedSettings } from "./backend.ts";

function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
function rejects(action: () => unknown) {
  let rejected = false;
  try {
    action();
  } catch {
    rejected = true;
  }
  assert(rejected);
}
const raw = JSON.parse(
  await Deno.readTextFile(new URL("profiles.json", import.meta.url)),
);
const settings: SeedSettings = {
  key: "test-admin-key",
  host: `db.${testProjectRef}.supabase.co`,
  user: "postgres",
  password: "test-password",
  port: "5432",
  database: "postgres",
};
Deno.test("all fifty fictional profiles have unique fixture identities, valid adult birthdays and demo labels", () => {
  const profiles = validateProfiles(
    raw,
    undefined,
    new Date("2026-10-24T12:00:00Z"),
  );
  assert(profiles.length === 50 && new Set(profiles.map(emailFor)).size === 50);
  assert(profiles.every((p) => p.goal.startsWith("Demo profile. ")));
});
Deno.test("seed validation rejects minors, duplicate identities/photos, path traversal and invalid choices", () => {
  for (
    const change of [
      { date_of_birth: "2020-01-01" },
      { date_of_birth: "1990-02-31" },
      { demo_id: raw[1].demo_id },
      { photo: { ...raw[0].photo, file: raw[1].photo.file } },
      { photo: { ...raw[0].photo, file: "../../secret.jpg" } },
      { profile_option_ids: ["golf", "golf"] },
      { goal: "Looks like a real account" },
    ]
  ) {
    const profiles = structuredClone(raw);
    Object.assign(profiles[0], change);
    rejects(() => validateProfiles(profiles));
  }
  const catalog = new Map([["golf", "sports"], ["gym", "sports"], [
    "tennis",
    "sports",
  ], ["running", "sports"]]);
  const profiles = structuredClone(raw);
  profiles[0].profile_option_ids = ["golf", "gym", "tennis", "running"];
  rejects(() => validateProfiles(profiles, catalog));
});
Deno.test("seeding accepts only the pinned test database, including its pooler identity", () => {
  assertTestDatabase(settings.host, settings.user, "postgres");
  assertTestDatabase(
    "aws-0-us-west-1.pooler.supabase.com",
    `postgres.${testProjectRef}`,
    "postgres",
  );
  for (
    const [host, user, db] of [
      ["db.pnlpdevgwenkkoqjgcui.supabase.co", "postgres", "postgres"],
      [
        "aws-0-us-west-1.pooler.supabase.com",
        "postgres.pnlpdevgwenkkoqjgcui",
        "postgres",
      ],
      [`db.${testProjectRef}.supabase.co`, "postgres", "other"],
      ["attacker.example", `postgres.${testProjectRef}`, "postgres"],
    ]
  ) rejects(() => assertTestDatabase(host, user, db));
});
Deno.test("matching email alone never grants seed ownership for update or cleanup", () => {
  const profile = validateProfiles(raw)[0];
  const user = {
    id: "00000000-0000-0000-0000-000000000041",
    email: emailFor(profile),
    app_metadata: { demo_seed: seedTag, demo_id: profile.demo_id },
  };
  assert(ownedUser(user, profile));
  assert(!ownedUser({ ...user, app_metadata: {} }, profile));
  assert(
    !ownedUser({
      ...user,
      app_metadata: { demo_seed: seedTag, demo_id: "demo-99" },
    }, profile),
  );
  assert(!ownedUser({ ...user, id: "not-a-uuid" }, profile));
});
Deno.test("Auth creation uses the test project, reserved addresses and server-owned seed tags without invitations", async () => {
  const profile = validateProfiles(raw)[0];
  let called = false;
  const backend = new SeedBackend(
    settings,
    ((url, init) => {
      assert(
        String(url) ===
            `https://${testProjectRef}.supabase.co/auth/v1/admin/users` &&
          init?.method === "POST",
      );
      const body = JSON.parse(String(init.body));
      assert(
        body.email === emailFor(profile) &&
          body.app_metadata.demo_seed === seedTag && !body.password,
      );
      assert(new Headers(init.headers).get("apikey") === settings.key);
      called = true;
      return Promise.resolve(
        Response.json({ id: "00000000-0000-0000-0000-000000000041", ...body }),
      );
    }) as typeof fetch,
  );
  assert(ownedUser(await backend.createUser(profile), profile) && called);
});
Deno.test("cleanup deletes Storage bytes before Auth and stops if file removal fails", async () => {
  const id = "00000000-0000-0000-0000-000000000041";
  const paths: string[] = [];
  const backend = new SeedBackend(
    settings,
    ((url, init) => {
      paths.push(new URL(String(url)).pathname);
      assert(init?.method === "DELETE");
      if (paths.length === 1) {
        assert(
          JSON.stringify(JSON.parse(String(init.body)).prefixes) ===
            JSON.stringify([
              `${id}/profile.jpg`,
              `${id}/profile-2.jpg`,
              `${id}/profile-3.jpg`,
              `${id}/selfie.jpg`,
            ]),
        );
      }
      return Promise.resolve(Response.json({}));
    }) as typeof fetch,
  );
  await backend.removeUser(id);
  assert(
    paths.length === 2 && paths[0].startsWith("/storage/") &&
      paths[1].startsWith("/auth/"),
  );
  let count = 0;
  const failed = new SeedBackend(
    settings,
    (() => {
      count++;
      return Promise.resolve(
        Response.json({ secret: "not printed" }, { status: 503 }),
      );
    }) as typeof fetch,
  );
  let error = "";
  try {
    await failed.removeUser(id);
  } catch (e) {
    error = String(e);
  }
  assert(
    count === 1 && error.includes("503") && !error.includes("not printed"),
  );
});

Deno.test("gallery assignment is stable and covers one, two and three total photos", () => {
  const pool = validateGallery([
    {
      file: "photos/gallery-desert.jpg",
      source_url: "https://example.com/desert",
      license: "Pexels",
    },
    {
      file: "photos/gallery-mountain.jpg",
      source_url: "https://example.com/mountain",
      license: "Pexels",
    },
  ]);
  const profiles = validateProfiles(raw);
  const counts = [0, 0, 0];
  for (const profile of profiles) {
    const selected = galleryFor(profile, pool);
    counts[selected.length]++;
    assert(
      new Set(selected.map((photo) => photo.file)).size === selected.length,
    );
    assert(
      JSON.stringify(selected) === JSON.stringify(galleryFor(profile, pool)),
    );
  }
  assert(JSON.stringify(counts) === "[17,17,16]");
  assert(galleryFor(profiles[0], []).length === 0);
  for (
    const value of [
      null,
      [pool[0]],
      [{ ...pool[0], file: "../../secret.jpg" }, pool[1]],
      [pool[0], pool[0]],
      [{ ...pool[0], license: "" }, pool[1]],
    ]
  ) {
    rejects(() => validateGallery(value));
  }
});

Deno.test("gallery upload precedes stale-slot removal; failed upload never removes photos or enables visibility", async () => {
  const id = "00000000-0000-0000-0000-000000000041";
  class FakeBackend extends SeedBackend {
    queries: string[] = [];
    override sql(query: string): Promise<string> {
      this.queries.push(query);
      return Promise.resolve("");
    }
  }
  const requests: { path: string; method: string; body: unknown }[] = [];
  const backend = new FakeBackend(
    settings,
    ((url, init) => {
      requests.push({
        path: new URL(String(url)).pathname,
        method: init!.method!,
        body: init!.body,
      });
      return Promise.resolve(Response.json({}));
    }) as typeof fetch,
  );
  await backend.upload(id, new Uint8Array([1]), [new Uint8Array([2])]);
  assert(
    requests[0].path.endsWith("/profile.jpg") &&
      requests[1].path.endsWith("/profile-2.jpg"),
  );
  assert(requests[2].method === "DELETE");
  assert(
    JSON.stringify(JSON.parse(String(requests[2].body)).prefixes) ===
      JSON.stringify([`${id}/profile-3.jpg`]),
  );
  assert(backend.queries.length === 1);
  requests.length = 0;
  await backend.upload(id, new Uint8Array([1]));
  assert(requests.length === 1 && requests[0].method === "POST");
  let attempts = 0;
  const failed = new FakeBackend(
    settings,
    (() => {
      attempts++;
      return Promise.resolve(Response.json({}, { status: 503 }));
    }) as typeof fetch,
  );
  let rejected = false;
  try {
    await failed.upload(id, new Uint8Array([1]), []);
  } catch {
    rejected = true;
  }
  assert(rejected && attempts === 1 && failed.queries.length === 0);
});
