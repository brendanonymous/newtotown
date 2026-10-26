import { profilePhotoURLs, signProfilePhotos } from "./profile-photos.ts";
const id = "00000000-0000-0000-0000-000000000041";
const card = {
  id,
  first_name: "Alex",
  job_title: "Designer",
  goal: "Coffee",
  city: "Scottsdale",
};
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}

Deno.test("gallery signs only existing, authorized profile slots in stable order", async () => {
  const paths = [`${id}/profile-3.jpg`, `${id}/profile.jpg`];
  const send: typeof fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body));
    if (body.people) {
      assert(JSON.stringify(body.people) === JSON.stringify([id]));
      return Promise.resolve(Response.json(paths));
    }
    assert(body.expiresIn === 60);
    assert(JSON.stringify(body.paths) === JSON.stringify(paths));
    return Promise.resolve(Response.json(paths.map((path) => ({
      path,
      signedURL: `/object/sign/private-photos/${path}?token=short`,
    }))));
  };
  const urls = await signProfilePhotos(
    [card, card],
    "https://test.supabase.co",
    {},
    send,
  );
  const gallery = profilePhotoURLs(id, urls);
  assert(
    gallery.length === 2 && gallery[0].includes("/profile.jpg?") &&
      gallery[1].includes("/profile-3.jpg?"),
  );
});

Deno.test("gallery rejects selfies, other owners, duplicate paths, missing main photos and incomplete signatures", async () => {
  for (
    const paths of [
      [`${id}/selfie.jpg`],
      [`${id}/profile.jpg`, `${id}/profile-4.jpg`],
      [`${id}/profile.jpg`, "other/profile-2.jpg"],
      [`${id}/profile-2.jpg`],
      [`${id}/profile.jpg`, `${id}/profile.jpg`],
    ]
  ) {
    let calls = 0;
    let rejected = false;
    try {
      await signProfilePhotos(
        [card],
        "https://test.supabase.co",
        {},
        (() => {
          calls++;
          return Promise.resolve(Response.json(paths));
        }) as typeof fetch,
      );
    } catch {
      rejected = true;
    }
    assert(rejected && calls === 1);
  }
  let rejected = false;
  try {
    await signProfilePhotos(
      [card],
      "https://test.supabase.co",
      {},
      ((_url, init) =>
        Promise.resolve(Response.json(
          JSON.parse(String(init?.body)).people
            ? [`${id}/profile.jpg`, `${id}/profile-2.jpg`]
            : [{
              path: `${id}/profile.jpg`,
              signedURL:
                `/object/sign/private-photos/${id}/profile.jpg?token=x`,
            }],
        ))) as typeof fetch,
    );
  } catch {
    rejected = true;
  }
  assert(rejected);
});
