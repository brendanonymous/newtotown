# Profile image loading

The first phase was approved October 24, 2026: in-memory reuse and display-sized decoding. No thumbnails, storage rules, signed-URL lifetimes, upload quality, or paid services changed.

## Implementation

`AuthorizedPhotoLoader` in `NewToTownCore/Photos` coalesces identical downloads and keeps up to 8 MiB of compressed bytes using least-recently-used eviction. Its dedicated ephemeral URLSession has no URL/disk cache. Only HTTPS profile-photo URLs with a profile UUID and signed-token expiry are accepted; selfies and unsigned URLs are rejected. Cache keys retain the entire signed URL, including its token. Reading the token's expiry bounds local reuse; the client does not verify or replace Storage's signature validation. Expired results are not served to new requests, and nothing is cached longer than 60 seconds.

`App/Images/ProfileImageStore` keeps up to 32 MiB of decoded bitmaps, keyed by validated photo resource and display pixel size. A resource keeps the origin, bucket/path, photo slot, and all query parameters except `token`, so renewed signatures can reuse a still-valid bitmap. Every incoming URL is checked for a profile slot and unexpired token before lookup; cache hits never extend the original downloaded source’s deadline. It deduplicates decode work and uses `ProfileImageDecoder` off the main actor. The decoder honors orientation and creates only the pixels required by the view, capped at the existing 1200-pixel upload size. A 48-point avatar on a 3x display requests a 144-pixel decode. These budgets cover the caches, not every image retained by visible SwiftUI views.

`SignedInView` owns the store under its existing account-UUID identity. Leaving that scope clears both caches and invalidates pending results. Reporting evicts the affected peer and rejects late results without removing unrelated photos. Cancelling one consumer does not cancel a shared request needed by another. Avatars and public profile cards share `RemoteProfilePhoto`; rounding and shadows remain with their existing presentation components. Connections and Messages use lazy stacks to defer offscreen image views.

The owner's profile retains its already loaded image across tab switches. My photos invalidates it before editing; closing the sheet reloads it. Pull-to-refresh also reloads it. Decoding runs off the main actor, and generation/cancellation checks reject late results. A photo changed on another device may remain visible until this refresh or a new sign-in.

## Benefits and tradeoffs

Repeated views can reuse one download and a decoded bitmap, and small avatars consume much less decoded memory. The initial transfer still downloads the current JPEG, already resized at upload to a maximum of 1200 pixels. A renewed signature can reuse a decoded image for the same resource until its original deadline. A replacement at the same path may therefore show the previous image for the remainder of that interval (at most 60 seconds); no photo revision metadata is available yet. Expiry, account boundaries, and reporting take priority over cache hit rates. Already displayed/downloaded pixels cannot be remotely recalled.

The cache is not persisted between app launches. No cache key uses a profile ID alone. Both a currently valid incoming photo URL and a still-valid downloaded source are required for decoded reuse. URL expiry is not extended, selfies are excluded, and photos remain private. Real-device cold/warm timings on Wi-Fi and cellular remain an acceptance check; automated results do not establish a percentage latency improvement.

## Validation

Swift tests cover shared requests, cancelled consumers, expiry, full-URL replacement keys, bounded byte eviction, renewed decoded-resource identities, expired/unsigned decoded identities, origin/slot/query separation, failed downloads, account clearing, late results, reported-peer eviction, unsigned/selfie URLs, and oversized responses. `scripts/PhotoImageDecoderChecks.swift` compiles against the actual app decoder on macOS and checks avatar/card pixel sizes, bitmap cost, and malformed input without needing a simulator. Offline UI fixtures supply real JPEG bytes through the shared store, with no Supabase request or real user photo. Discovery tests count downloads, renew signatures after decisions, and gate acknowledgements to verify bounded preloading, reuse, pending feedback, and failure recovery. Reduce Motion should also be checked on a device.

## Possible second phase

Separate small avatar files would reduce first-load bytes. They require coordinated upload/replacement/deletion, revision metadata, storage access review, and an existing-photo backfill or fallback. Separate thumbnails are not implemented; bounded next-candidate preloading is described below.

Supabase's [managed image transformations](https://supabase.com/docs/guides/storage/serving/image-transformations) are an alternative, currently documented for Pro or above. Keeping the existing files and decoding locally avoids that plan requirement. Docs and relevant changelog checked October 24, 2026.

## Three-photo galleries

The current card creates at most three image views together, so tapping does not wait for a newly started request or an expired unused URL. Each view uses the same bounded account-scoped store and display-sized decoding. This downloads additional gallery photos upfront even if the viewer never taps, trading some bandwidth and visible-view memory for immediate cycling. Signed-link/cache lifetimes are unchanged. Discovery separately preloads only the next candidate’s main photo. Owner cards load all three files concurrently and decode away from the main actor. Selfies remain excluded from both card paths.

## Discovery decisions and preloading

While Discovery is selected and the feed is ready, `DiscoveryPhotoPreloader` warms only the next candidate’s main photo through the shared store, using the current card’s exact display pixel size. It does not fetch later candidates or their extra photos. Leaving the tab or changing eligibility stops scheduling; an already shared download may still finish within the existing cache budget. Speculation fails silently and never delays a decision; a displayed photo can retry normally.

The chosen decision button shows progress and both decisions remain disabled until the server responds. The existing card remains visible until success. The next card slides/fades for 200 ms; Reduce Motion disables that animation. Failed or cancelled decisions retain the existing reconciliation behavior: discard uncertain feed state and offer refresh/retry. Callbacks include the displayed profile ID, so a tap from an outgoing card cannot decide on its replacement.

Preloading spends bandwidth on one main photo that may never be viewed. It helps when the user pauses on a card; rapid decisions, slow connections, expired links, or cache eviction can still show loading. No latency percentage is claimed without device measurements. The raw-byte cache still uses full signed URLs; decoded reuse is sufficient for the matching preload/display size.
