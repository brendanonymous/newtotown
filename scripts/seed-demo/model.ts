export const testProjectRef = "acmrnolvakubxnaxwpzt";
export const seedTag = "newtotown-demo-v1";
export type DemoProfile = {
  demo_id: string;
  first_name: string;
  job_title: string;
  goal: string;
  date_of_birth: string;
  city: "Scottsdale";
  profile_option_ids: string[];
  filter_option_ids: string[];
  photo: { file: string; source_url: string; license: string };
};

function selections(
  value: unknown,
  catalog?: Map<string, string>,
): value is string[] {
  if (
    !Array.isArray(value) || value.length > 15 ||
    new Set(value).size !== value.length
  ) return false;
  const counts = new Map<string, number>();
  return value.every((id) => {
    if (typeof id !== "string" || !/^[a-z][a-z0-9_]{0,63}$/.test(id)) {
      return false;
    }
    if (!catalog) return true;
    const category = catalog.get(id);
    if (!category) return false;
    const count = (counts.get(category) ?? 0) + 1;
    counts.set(category, count);
    return count <= 3;
  });
}
export function validateProfiles(
  value: unknown,
  catalog?: Map<string, string>,
  today = new Date(),
): DemoProfile[] {
  if (!Array.isArray(value) || value.length !== 50) {
    throw new Error("Expected exactly 50 demo profiles");
  }
  const ids = new Set<string>();
  const photos = new Set<string>();
  const cutoff = new Date(today);
  cutoff.setUTCFullYear(cutoff.getUTCFullYear() - 18);
  for (const profile of value) {
    const birth = new Date(profile?.date_of_birth + "T00:00:00Z");
    if (
      !profile || !/^demo-\d{2}$/.test(profile.demo_id) ||
      ids.has(profile.demo_id) ||
      typeof profile.first_name !== "string" || !profile.first_name.trim() ||
      profile.first_name.length > 40 ||
      typeof profile.job_title !== "string" || !profile.job_title.trim() ||
      profile.job_title.length > 80 ||
      typeof profile.goal !== "string" ||
      !profile.goal.startsWith("Demo profile. ") || profile.goal.length > 280 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(profile.date_of_birth) ||
      !Number.isFinite(birth.getTime()) ||
      birth.toISOString().slice(0, 10) !== profile.date_of_birth ||
      birth > cutoff || profile.city !== "Scottsdale" ||
      !selections(profile.profile_option_ids, catalog) ||
      !selections(profile.filter_option_ids, catalog) ||
      !profile.photo ||
      !/^(photos\/\d{2}\.(jpg|jpeg|png)|\.\.\/\.\.\/avatars\/uifaces-human-avatar(?: \(\d+\))?\.jpg)$/
        .test(profile.photo.file) ||
      photos.has(profile.photo.file) ||
      typeof profile.photo.source_url !== "string" ||
      typeof profile.photo.license !== "string"
    ) {
      throw new Error(`Invalid demo profile: ${profile?.demo_id ?? "unknown"}`);
    }
    ids.add(profile.demo_id);
    photos.add(profile.photo.file);
  }
  return value;
}
export function emailFor(profile: DemoProfile): string {
  return `${profile.demo_id}@newtotown-test.invalid`;
}
export type SeedUser = {
  id: string;
  email?: string;
  app_metadata?: Record<string, unknown>;
};
export function ownedUser(user: SeedUser, profile: DemoProfile): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    user.id,
  ) && user.email === emailFor(profile) &&
    user.app_metadata?.demo_seed === seedTag &&
    user.app_metadata?.demo_id === profile.demo_id;
}
export function assertTestDatabase(
  host: string,
  user: string,
  database: string,
) {
  const direct = host === `db.${testProjectRef}.supabase.co` &&
    user === "postgres";
  const pooler = host.endsWith(".pooler.supabase.com") &&
    user === `postgres.${testProjectRef}`;
  if ((!direct && !pooler) || database !== "postgres") {
    throw new Error(
      "Refusing database outside the approved isolated test project",
    );
  }
}
