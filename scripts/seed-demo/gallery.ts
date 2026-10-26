import type { DemoProfile } from "./model.ts";

export type GalleryPhoto = {
  file: string;
  source_url: string;
  license: string;
};

/** A shared local stock-photo pool, independent of the fifty main portraits. */
export function validateGallery(value: unknown): GalleryPhoto[] {
  if (!Array.isArray(value) || (value.length > 0 && value.length < 2)) {
    throw new Error(
      "Gallery pool must be empty (disabled) or contain at least two photos",
    );
  }
  const files = new Set<string>();
  for (const photo of value) {
    if (
      !photo || typeof photo.file !== "string" ||
      !/^photos\/gallery-[a-z0-9-]+\.(jpg|jpeg|png)$/.test(photo.file) ||
      files.has(photo.file) || typeof photo.source_url !== "string" ||
      !photo.source_url.startsWith("https://") ||
      typeof photo.license !== "string" || !photo.license.trim()
    ) {
      throw new Error(
        "Invalid gallery photo: use a local gallery filename, HTTPS source and license",
      );
    }
    files.add(photo.file);
  }
  return value;
}

/** Stable 0/1/2 distribution; rerunning never reshuffles a profile's gallery. */
export function galleryFor(
  profile: DemoProfile,
  pool: GalleryPhoto[],
): GalleryPhoto[] {
  if (pool.length === 0) return [];
  const index = Number(profile.demo_id.slice(5)) - 1;
  return Array.from(
    { length: index % 3 },
    (_, offset) => pool[(index + offset) % pool.length],
  );
}
