import { type PublicInterest, readInterests } from "./interests.ts";

export type Card = {
  id: string;
  first_name: string;
  job_title: string;
  goal: string;
  city: string;
  interests?: PublicInterest[];
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Only authorized feed projections may reach this profile-only signer. */
export async function signProfilePhotos(
  profiles: Card[],
  projectURL: string,
  headers: Record<string, string>,
  send: typeof fetch,
): Promise<Map<string, string>> {
  const paths = [...new Set(profiles.map((card) => `${card.id}/profile.jpg`))];
  const urls = new Map<string, string>();
  if (!paths.length) return urls;
  const signed = await send(
    `${projectURL}/storage/v1/object/sign/private-photos`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ paths, expiresIn: 60 }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!signed.ok) throw new Error("Photos unavailable");
  const results = await signed.json();
  if (!Array.isArray(results)) throw new Error("Invalid photo response");
  for (const item of results) {
    if (
      paths.includes(item.path) && typeof item.signedURL === "string" &&
      !item.error
    ) {
      const expected = `/object/sign/private-photos/${item.path}?`;
      if (!item.signedURL.startsWith(expected)) {
        throw new Error("Unexpected photo URL");
      }
      urls.set(item.path, `${projectURL}/storage/v1${item.signedURL}`);
    }
  }
  if (urls.size !== paths.length) throw new Error("Missing photos");
  return urls;
}

export function readCards(value: unknown, maximum: number): Card[] {
  if (!Array.isArray(value) || value.length > maximum) {
    throw new Error("Invalid cards");
  }
  return value.map((card) => {
    if (
      typeof card.id !== "string" || !uuid.test(card.id) ||
      ![card.first_name, card.job_title, card.goal, card.city].every((field) =>
        typeof field === "string"
      )
    ) throw new Error("Invalid card");
    // Explicit projection prevents future RPC fields from accidentally exposing private data.
    return {
      id: card.id.toLowerCase(),
      first_name: card.first_name,
      job_title: card.job_title,
      goal: card.goal,
      city: card.city,
      ...(card.interests === undefined
        ? {}
        : { interests: readInterests(card.interests) }),
    };
  });
}
