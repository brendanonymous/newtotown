import { interestID } from "../_shared/interests.ts";

type Command = { action: "load" } | {
  action: "save";
  selection_kind: "profile" | "filters";
  option_ids: string[];
};
export function command(value: unknown): Command | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) return;
  const item = value as Record<string, unknown>;
  const keys = Object.keys(item).sort().join(",");
  if (item.action === "load" && keys === "action") return { action: "load" };
  if (
    item.action === "save" && keys === "action,option_ids,selection_kind" &&
    (item.selection_kind === "profile" || item.selection_kind === "filters") &&
    Array.isArray(item.option_ids) && item.option_ids.length <= 15 &&
    item.option_ids.every(interestID) &&
    new Set(item.option_ids).size === item.option_ids.length
  ) {
    return {
      action: "save",
      selection_kind: item.selection_kind,
      option_ids: item.option_ids,
    };
  }
}

/** Validate and project the owner response; unknown RPC fields never reach clients. */
export function ownerInterests(value: unknown) {
  if (!value || typeof value !== "object") throw new Error("Invalid interests");
  const item = value as Record<string, unknown>;
  if (!Array.isArray(item.categories) || item.categories.length !== 5) {
    throw new Error("Invalid catalog");
  }
  const categoryIDs = new Set<string>();
  const options = new Map<string, string>();
  const categories = item.categories.map((category) => {
    if (
      !interestID(category.id) || categoryIDs.has(category.id) ||
      typeof category.title !== "string" || !category.title.trim() ||
      category.title.length > 80 ||
      !Array.isArray(category.options) || category.options.length > 100
    ) throw new Error("Invalid category");
    categoryIDs.add(category.id);
    return {
      id: category.id,
      title: category.title,
      options: category.options.map((option: Record<string, unknown>) => {
        if (
          !option || !interestID(option.id) || options.has(option.id) ||
          typeof option.title !== "string" || !option.title.trim() ||
          option.title.length > 80
        ) throw new Error("Invalid option");
        options.set(option.id, category.id);
        return { id: option.id, title: option.title };
      }),
    };
  });
  const selections = (value: unknown): string[] => {
    if (
      !Array.isArray(value) || value.length > 15 ||
      new Set(value).size !== value.length
    ) {
      throw new Error("Invalid selections");
    }
    const counts = new Map<string, number>();
    return value.map((id) => {
      const category = options.get(id);
      if (!category) throw new Error("Unknown option");
      const count = (counts.get(category) ?? 0) + 1;
      if (count > 3) throw new Error("Too many selections");
      counts.set(category, count);
      return id;
    });
  };
  return {
    categories,
    profile_option_ids: selections(item.profile_option_ids),
    filter_option_ids: selections(item.filter_option_ids),
  };
}
