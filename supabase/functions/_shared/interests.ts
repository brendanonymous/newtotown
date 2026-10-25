export type PublicInterest = { id: string; category_id: string; title: string };
export const interestID = (value: unknown): value is string =>
  typeof value === "string" && /^[a-z][a-z0-9_]{0,63}$/.test(value);

/** Explicit public fields only; private Discovery filters never belong on cards. */
export function readInterests(value: unknown): PublicInterest[] {
  if (!Array.isArray(value) || value.length > 15) {
    throw new Error("Invalid interests");
  }
  const seen = new Set<string>();
  const counts = new Map<string, number>();
  return value.map((item) => {
    if (
      !item || !interestID(item.id) || !interestID(item.category_id) ||
      typeof item.title !== "string" || !item.title.trim() ||
      item.title.length > 80 || seen.has(item.id)
    ) throw new Error("Invalid interest");
    seen.add(item.id);
    const count = (counts.get(item.category_id) ?? 0) + 1;
    if (count > 3) throw new Error("Invalid interest count");
    counts.set(item.category_id, count);
    return { id: item.id, category_id: item.category_id, title: item.title };
  });
}
