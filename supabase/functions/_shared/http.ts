/** Keep all endpoint responses uncached and upstream details out of error bodies. */
export function jsonReply(status: number, value: unknown): Response {
  return Response.json(value, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

/** Bound bytes while reading, rather than buffering an unlimited body first. */
export async function readJSON(
  request: Request,
  maximumBytes: number,
): Promise<unknown> {
  if (!request.body) throw new Error("Missing body");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maximumBytes) {
        await reader.cancel();
        throw new Error("Body too large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}
