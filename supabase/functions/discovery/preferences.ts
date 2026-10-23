export type AgePreferences = {
  minimum_age: number;
  maximum_age: number | null;
};

export function agePreferences(value: unknown): AgePreferences | undefined {
  if (!value || typeof value !== "object") return;
  const item = value as Record<string, unknown>;
  if (
    !Number.isInteger(item.minimum_age) || Number(item.minimum_age) < 18 ||
    Number(item.minimum_age) > 2147483647
  ) return;
  if (
    item.maximum_age !== null &&
    (!Number.isInteger(item.maximum_age) ||
      Number(item.maximum_age) < Number(item.minimum_age) ||
      Number(item.maximum_age) > 2147483647)
  ) return;
  return {
    minimum_age: Number(item.minimum_age),
    maximum_age: item.maximum_age === null ? null : Number(item.maximum_age),
  };
}
