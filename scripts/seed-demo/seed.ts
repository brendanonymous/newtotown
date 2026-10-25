import { SeedBackend } from "./backend.ts";
import {
  emailFor,
  ownedUser,
  testProjectRef,
  validateProfiles,
} from "./model.ts";

const mode = Deno.args[0] ?? "--dry-run";
if (
  Deno.args.length > 1 || !["--dry-run", "--apply", "--cleanup"].includes(mode)
) {
  throw new Error("Usage: seed.ts [--dry-run | --apply | --cleanup]");
}
const base = new URL("./", import.meta.url);
const profiles = validateProfiles(
  JSON.parse(await Deno.readTextFile(new URL("profiles.json", base))),
);
const missing: string[] = [];
if (mode !== "--cleanup") {
  for (const profile of profiles) {
    try {
      const stat = await Deno.stat(new URL(profile.photo.file, base));
      if (!stat.isFile || stat.size === 0 || stat.size > 25 * 1024 * 1024) {
        missing.push(`${profile.demo_id}: missing/oversized portrait`);
      }
    } catch {
      missing.push(`${profile.demo_id}: portrait not found`);
    }
    if (
      !profile.photo.source_url.startsWith("https://") ||
      !profile.photo.license.trim()
    ) missing.push(`${profile.demo_id}: add source URL and license`);
  }
}
if (mode === "--dry-run") {
  console.log(
    `Validated ${profiles.length} fictional profiles for test project ${testProjectRef}. No network calls or writes.`,
  );
  console.log(
    `${missing.length} photo/source items need preparation before --apply.`,
  );
} else {
  if (missing.length) {
    throw new Error(
      `Prepare portraits and source/license records before applying (${missing.length} items). See README.md.`,
    );
  }
  const backend = new SeedBackend({
    key: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    host: Deno.env.get("PGHOST") ?? "",
    user: Deno.env.get("PGUSER") ?? "",
    password: Deno.env.get("PGPASSWORD") ?? "",
    port: Deno.env.get("PGPORT") ?? "5432",
    database: Deno.env.get("PGDATABASE") ?? "postgres",
  });
  const users = await backend.users();
  // Refuse collisions for the entire run before creating, modifying or deleting anything.
  for (const profile of profiles) {
    const existing = users.find((user) => user.email === emailFor(profile));
    if (existing && !ownedUser(existing, profile)) {
      throw new Error(`Refusing unowned account: ${profile.demo_id}`);
    }
  }
  if (mode === "--cleanup") {
    for (const profile of profiles) {
      const user = users.find((user) => ownedUser(user, profile));
      if (user) {
        await backend.removeUser(user.id);
        console.log(`Removed ${profile.demo_id}`);
      }
    }
  } else {
    const catalogRows = JSON.parse(
      await backend.sql(
        "select coalesce(json_agg(json_build_object('id',id,'category_id',category_id)),'[]'::json) from private.interest_options where active;",
      ),
    );
    validateProfiles(
      profiles,
      new Map(
        catalogRows.map((
          item: { id: string; category_id: string },
        ) => [item.id, item.category_id]),
      ),
    );
    const review = await backend.sql(
      "select coalesce((select photo_review_required::text from public.pilot_features where id),'true');",
    );
    if (review !== "false") {
      throw new Error(
        "Test photo review must be off; seeding never approves identities or fabricates selfies",
      );
    }
    // Decode every portrait before any remote mutations. The helper is compiled once.
    const temporary = await Deno.makeTempDir({ prefix: "newtotown-demo-" });
    try {
      const executable = `${temporary}/normalize-photo`;
      const compiled = await new Deno.Command("swiftc", {
        args: [
          new URL("NormalizePhoto.swift", base).pathname,
          "-o",
          executable,
        ],
        stdout: "null",
        stderr: "piped",
      }).output();
      if (!compiled.success) {
        throw new Error(
          "Could not compile the macOS portrait helper; install Xcode command-line tools",
        );
      }
      const photos = new Map<string, Uint8Array>();
      for (const profile of profiles) {
        const output = `${temporary}/${profile.demo_id}.jpg`;
        const result = await new Deno.Command(executable, {
          args: [new URL(profile.photo.file, base).pathname, output],
          stdout: "null",
          stderr: "null",
        }).output();
        if (!result.success) {
          throw new Error(`Invalid portrait: ${profile.demo_id}`);
        }
        const data = await Deno.readFile(output);
        if (!data.length || data.length > 3 * 1024 * 1024) {
          throw new Error(`Portrait exceeds upload limit: ${profile.demo_id}`);
        }
        photos.set(profile.demo_id, data);
      }
      for (const profile of profiles) {
        const user = users.find((user) => ownedUser(user, profile)) ??
          await backend.createUser(profile);
        if (!ownedUser(user, profile)) {
          throw new Error(`Unexpected created account: ${profile.demo_id}`);
        }
        await backend.saveProfile(user.id, profile);
        await backend.upload(user.id, photos.get(profile.demo_id)!);
        console.log(`Seeded ${profile.demo_id}`);
      }
    } finally {
      await Deno.remove(temporary, { recursive: true });
    }
  }
}
