import {
  assertTestDatabase,
  type DemoProfile,
  emailFor,
  seedTag,
  type SeedUser,
  testProjectRef,
} from "./model.ts";

const literal = (value: string) => "'" + value.replaceAll("'", "''") + "'";
const array = (values: string[]) =>
  `array[${values.map(literal).join(",")}]::text[]`;

export type SeedSettings = {
  key: string;
  host: string;
  user: string;
  password: string;
  port: string;
  database: string;
};

/** Privileged CLI-only transport. This module is never imported into the iPhone app. */
export class SeedBackend {
  constructor(
    private readonly settings: SeedSettings,
    private readonly send: typeof fetch = fetch,
  ) {
    if (!settings.key) {
      throw new Error(
        "Set SUPABASE_SERVICE_ROLE_KEY locally; never commit or paste it into chat",
      );
    }
    assertTestDatabase(settings.host, settings.user, settings.database);
    if (
      !/^\d+$/.test(settings.port) || Number(settings.port) < 1 ||
      Number(settings.port) > 65535
    ) throw new Error("Invalid database port");
  }
  async sql(query: string): Promise<string> {
    const child = new Deno.Command("psql", {
      args: ["-X", "-qAt", "-v", "ON_ERROR_STOP=1"],
      clearEnv: true,
      stdin: "piped",
      stdout: "piped",
      stderr: "piped",
      env: {
        PATH: Deno.env.get("PATH") ?? "/usr/local/bin:/usr/bin:/bin",
        PGHOST: this.settings.host,
        PGUSER: this.settings.user,
        PGPASSWORD: this.settings.password,
        PGPORT: this.settings.port,
        PGDATABASE: "postgres",
        PGSSLMODE: "require",
        PGCONNECT_TIMEOUT: "15",
        PGOPTIONS: "-c statement_timeout=30000",
      },
    }).spawn();
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode(query));
    await writer.close();
    const result = await child.output();
    if (!result.success) {
      throw new Error(
        "Database command failed; check the test connection, migrations and privileges",
      );
    }
    return new TextDecoder().decode(result.stdout).trim();
  }
  private async api(
    path: string,
    method: string,
    body?: string | Uint8Array,
    extraHeaders: Record<string, string> = {},
  ) {
    const response = await this.send(
      `https://${testProjectRef}.supabase.co${path}`,
      {
        method,
        redirect: "error",
        headers: {
          apikey: this.settings.key,
          Authorization: `Bearer ${this.settings.key}`,
          "Content-Type": "application/json",
          ...extraHeaders,
        },
        body: body instanceof Uint8Array ? new Uint8Array(body).buffer : body,
        signal: AbortSignal.timeout(30000),
      },
    );
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`Test backend request failed (${response.status})`);
    }
    return response;
  }
  async users(): Promise<SeedUser[]> {
    const users: SeedUser[] = [];
    for (let page = 1; page <= 100; page++) {
      const result = await (await this.api(
        `/auth/v1/admin/users?page=${page}&per_page=1000`,
        "GET",
      )).json();
      if (!Array.isArray(result.users)) {
        throw new Error("Invalid Auth user response");
      }
      users.push(...result.users);
      if (result.users.length < 1000) return users;
    }
    throw new Error(
      "Unexpectedly large test account list; no writes performed",
    );
  }
  async createUser(profile: DemoProfile): Promise<SeedUser> {
    // Admin creation sends no email/SMS. No password and a reserved .invalid address.
    const user = await (await this.api(
      "/auth/v1/admin/users",
      "POST",
      JSON.stringify({
        email: emailFor(profile),
        email_confirm: true,
        app_metadata: { demo_seed: seedTag, demo_id: profile.demo_id },
      }),
    )).json();
    return user;
  }
  async saveProfile(id: string, profile: DemoProfile) {
    await this.sql(`begin;
      insert into public.account_agreements(user_id,version) values (${
      literal(id)
    },'onboarding-v1') on conflict do nothing;
      insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement)
        values (${literal(id)},${literal(profile.first_name)},${
      literal(profile.job_title)
    },${literal(profile.goal)},${
      literal(profile.date_of_birth)
    },'Scottsdale',true)
      on conflict(id) do update set first_name=excluded.first_name,job_title=excluded.job_title,goal=excluded.goal,date_of_birth=excluded.date_of_birth;
      select public.pilot_interests_save(${literal(id)},'profile',${
      array(profile.profile_option_ids)
    });
      select public.pilot_interests_save(${literal(id)},'filters',${
      array(profile.filter_option_ids)
    });
      commit;`);
  }
  async upload(id: string, photo: Uint8Array, additional?: Uint8Array[]) {
    if (additional && additional.length > 2) {
      throw new Error("At most two additional photos");
    }
    const photos = [photo, ...(additional ?? [])];
    const slots = ["profile.jpg", "profile-2.jpg", "profile-3.jpg"];
    for (const [index, bytes] of photos.entries()) {
      const response = await this.api(
        `/storage/v1/object/private-photos/${id}/${slots[index]}`,
        "POST",
        bytes,
        {
          "Content-Type": "image/jpeg",
          "x-upsert": "true",
          "cache-control": "0",
        },
      );
      await response.body?.cancel();
    }
    // Only reconcile extra slots when a gallery pool was explicitly configured.
    // Upload first so a failed replacement does not delete the previous gallery.
    if (additional !== undefined && photos.length < slots.length) {
      const response = await this.api(
        "/storage/v1/object/private-photos",
        "DELETE",
        JSON.stringify({
          prefixes: slots.slice(photos.length).map((slot) => `${id}/${slot}`),
        }),
      );
      await response.body?.cancel();
    }
    await this.sql(
      `select public.pilot_discovery_visibility(${literal(id)},true);`,
    );
  }
  async removeUser(id: string) {
    const response = await this.api(
      "/storage/v1/object/private-photos",
      "DELETE",
      JSON.stringify({
        prefixes: [
          `${id}/profile.jpg`,
          `${id}/profile-2.jpg`,
          `${id}/profile-3.jpg`,
          `${id}/selfie.jpg`,
        ],
      }),
    );
    await response.body?.cancel();
    const deleted = await this.api(`/auth/v1/admin/users/${id}`, "DELETE");
    await deleted.body?.cancel();
  }
}
