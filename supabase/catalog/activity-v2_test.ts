import { command, ownerInterests } from "../functions/interests/commands.ts";

const source = await Deno.readTextFile(
  new URL("./activity-v2.json", import.meta.url),
);
const taxonomy = JSON.parse(source) as {
  version: string;
  categories: {
    id: string;
    label: string;
    interest_placements: number;
    groups: { name: string; interest_ids: string[] }[];
  }[];
  interests: {
    id: string;
    label: string;
    category_ids: string[];
    age_restricted: boolean;
  }[];
};
const categories = [
  "gym",
  "sports",
  "wingman",
  "going_out",
  "outdoor",
  "food_drink",
  "gaming",
  "events",
  "explore_city",
  "hobby",
  "weekend",
  "casual_hang",
];
function assert(value: unknown, reason: string): asserts value {
  if (!value) throw new Error(reason);
}

Deno.test("canonical taxonomy bytes match the supplied handoff manifest", async () => {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(source)),
  );
  const hash = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  assert(
    hash === "40960f3c8b7ee2d3ff5035fb64ba4905ba9e89e781c167ad3e3ed792c8fc6bb4",
    "Unexpected source edits",
  );
});

Deno.test("catalog has the approved twelve categories and 557 canonical IDs", () => {
  assert(
    JSON.stringify(taxonomy.categories.map((item) => item.id)) ===
      JSON.stringify(categories),
    "Category IDs/order changed",
  );
  assert(taxonomy.interests.length === 557, "Wrong interest count");
  const ids = taxonomy.interests.map((item) => item.id);
  assert(new Set(ids).size === ids.length, "Duplicate canonical interest");
  for (const item of taxonomy.interests) {
    assert(/^[a-z0-9][a-z0-9_]{0,63}$/.test(item.id), "Invalid interest ID");
    assert(
      item.label.trim().length > 0 && item.label.length <= 80,
      "Invalid label",
    );
    assert(typeof item.age_restricted === "boolean", "Missing review metadata");
    assert(
      item.category_ids.length > 0 &&
        new Set(item.category_ids).size === item.category_ids.length,
      "Invalid category memberships",
    );
    assert(
      item.category_ids.every((id) => categories.includes(id)),
      "Unknown category",
    );
  }
});

Deno.test("all 595 placements resolve to exactly the canonical category links", () => {
  const links = new Set(
    taxonomy.interests.flatMap((item) =>
      item.category_ids.map((category) => `${category}:${item.id}`)
    ),
  );
  const placements = new Set<string>();
  for (const category of taxonomy.categories) {
    const ids = category.groups.flatMap((group) => group.interest_ids);
    assert(
      ids.length === category.interest_placements,
      "Wrong per-category count",
    );
    for (const id of ids) {
      const key = `${category.id}:${id}`;
      assert(
        links.has(key) && !placements.has(key),
        "Unknown or duplicate placement",
      );
      placements.add(key);
    }
  }
  assert(
    links.size === 595 && placements.size === links.size,
    "Wrong membership count",
  );
});

Deno.test("publication rule yields 507 available interests and fifty hidden interests", () => {
  assert(
    taxonomy.interests.filter((item) => !item.age_restricted).length === 507,
    "Wrong published count",
  );
  assert(
    taxonomy.interests.filter((item) => item.age_restricted).length === 50,
    "Wrong hidden count",
  );
  for (const id of ["cannabis_hangouts", "smoking_cigars", "whiskey_bars"]) {
    assert(
      taxonomy.interests.find((item) => item.id === id)?.age_restricted ===
        true,
      "Flagged tag lost review state",
    );
  }
  assert(
    taxonomy.interests.some((item) =>
      item.id === "board_games" && !item.age_restricted
    ),
    "Board Games should be available in v2",
  );
  assert(
    !taxonomy.interests.some((item) =>
      ["sports_betting", "professional_networking", "vaping", "sunset_drives"]
        .includes(item.id)
    ),
    "Unexpected legacy/excluded addition",
  );
});

Deno.test("a complete available selection fits the proposed 64 KiB boundary but exceeds v1", () => {
  const ids = taxonomy.interests.filter((item) => !item.age_restricted).map((
    item,
  ) => item.id);
  const request = {
    action: "save_interests",
    interest_ids: ids,
    complete_setup: true,
    selection_revision: 0,
  };
  const bytes = new TextEncoder().encode(JSON.stringify(request)).length;
  assert(
    bytes > 4096 && bytes < 65536,
    "Full selection must fit the proposed v2 request budget",
  );
  assert(command(request) === undefined, "V1 must not accept a v2 mutation");
  assert(
    command({ action: "save", selection_kind: "profile", option_ids: ids }) ===
      undefined,
    "V1 must retain its selection boundary",
  );
});

Deno.test("legacy catalog retains five categories and rejects a twelve-category replacement", () => {
  const legacy = {
    categories: [
      "sports_fitness",
      "outdoors",
      "food_drinks",
      "arts_entertainment",
      "social_hobbies",
    ].map((id) => ({ id, title: id, options: [] })),
    profile_option_ids: [],
    filter_option_ids: [],
  };
  assert(ownerInterests(legacy).categories.length === 5, "V1 contract changed");
  let rejected = false;
  try {
    ownerInterests({
      ...legacy,
      categories: categories.map((id) => ({ id, title: id, options: [] })),
    });
  } catch {
    rejected = true;
  }
  assert(rejected, "A v2 catalog must not be substituted into the v1 endpoint");
});
