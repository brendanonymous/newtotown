/** These are the only four keys permitted by the private-photos bucket policies. */
export async function removePrivatePhotos(
  projectURL: string,
  adminKey: string,
  userID: string,
  send: typeof fetch,
): Promise<boolean> {
  const response = await send(
    `${projectURL}/storage/v1/object/private-photos`,
    {
      method: "DELETE",
      signal: AbortSignal.timeout(15_000),
      headers: {
        apikey: adminKey,
        Authorization: `Bearer ${adminKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        prefixes: [
          `${userID}/profile.jpg`,
          `${userID}/profile-2.jpg`,
          `${userID}/profile-3.jpg`,
          `${userID}/selfie.jpg`,
        ],
      }),
    },
  );
  return response.ok;
}
