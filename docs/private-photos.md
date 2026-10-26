# Private photo upload and selfie capture

## Behavior

Open **Profile → My photos** to add up to three profile photos. The first is the main photo used by avatars and discovery eligibility. Tap a public profile photo to cycle; compact dots below the frame show the count and current position. In **My photos**, tap the image to open replacement, swipe horizontally to browse, and use the small top-right × to remove the current photo. Removing the first promotes the next. Removing the final saved photo immediately deletes it and any private selfie, without a confirmation alert; removing a photo that was never saved only clears the draft. Closing or swiping down with unsaved edits asks **Leave without saving?**, with **Keep editing** and **Discard changes**. Unchanged drafts and successful saves close without a warning.

Unsaved state compares the ordered photos and private selfie against the last successful load/save/removal snapshot, independently of whether the draft meets photo requirements. Reverting edits clears the warning; failed writes preserve it. `EditorSheet` owns the shared close confirmation, enabled only by the photo editor. A small UIKit [dismiss-attempt observer](https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdidattempttodismiss(_:)) handles swipe-down attempts and restores the existing presentation delegate when the draft becomes clean.

Each selection opens a native pinch-to-zoom and pan editor. **Use photo** accepts the crop into the draft; **Close** cancels it. **Save photos** uploads the draft and closes only on success. The crop editor, owner card, Discovery card, and conversation profile use the same available card width and existing 300-point height, rounding, and shadow. Crops are exported at that viewport's ratio; aspect-fill can trim a little differently on another screen size because the existing frame is width-responsive. Avatars retain their small square treatment. There is no new transition animation.

The picker requires no broad photo-library permission. ImageIO applies source orientation and downsamples to at most 1,200 pixels before editing. Cropping renders new pixels, then JPEG encoding strips EXIF/GPS metadata. Each file stays below the existing 3 MiB limit. Zooming a small image can reduce sharpness; export does not upscale it.

Consent remains the existing one-time [signup agreement](onboarding-agreement.md); legacy photo consent is still accepted. The server [review flag](photo-review-flag.md) defaults off. Its private selfie is separate from the three profile slots. When review is on, discovery eligibility still requires the approved main-photo/selfie versions, and additional photos remain unpublished until per-photo review exists. Selfies are never signed for another user. No automatic liveness or identity check is implied.

## Structure

- `NewToTownCore/Photos`: bounded gallery validation, draft edits, crop geometry, and authorized image loading.
- `NewToTownSupabase/Photos/SupabasePhotoService.swift`: ordered owner downloads, uploads, obsolete-slot removal, and account checks. The signed-in root constructs a service bound to its account UUID, matching the existing contact/messaging service pattern.
- `App/Features/Photos`: crop viewport/controller, crop editor, photo editor, camera, and metadata-free encoding.
- `App/DesignSystem/ProfilePhotoLayout.swift` and `ProfilePhotoGallery.swift`: shared frame, dots, and tap/VoiceOver cycling.
- `supabase/functions/_shared/profile-photos.ts`: validates metadata for authorized profile IDs, signs only existing gallery paths, and orders public URL arrays. Discovery and messaging reuse it.

## Storage and privacy

The private bucket permits exactly four owner-scoped keys: `<UUID>/profile.jpg`, `profile-2.jpg`, `profile-3.jpg`, and `selfie.jpg`. Existing main photos require no backfill. RLS checks ownership, a saved profile, and accepted consent on upload/replacement. A fourth profile slot, arbitrary paths, ownership transfer, and cross-account reads remain forbidden.

The service-only `pilot_profile_photo_paths(uuid[])` RPC returns existing profile paths in one bounded metadata batch; authenticated clients cannot invoke it. The Edge Functions must authorize public profile IDs before calling it. All returned paths and signatures are checked against those IDs. The `photo_url` field remains the main photo for old clients; `photo_urls` adds the ordered gallery. Private JPEG links still expire after 60 seconds.

Saving uploads occupied slots before removing obsolete ones. These Storage writes are individually retryable, not atomic: an interrupted save can leave some server slots updated. The UI retains the complete draft and stays open for retry. A failed upload never triggers deletion of old slots. Replacing/reordering the main photo invalidates any version-specific review approval as before.

Deletion removes all four keys through the Storage API before deleting Auth, then cascades profile/consent data. Seed cleanup also covers all four keys. Do not delete Storage metadata directly with SQL. Actual camera behavior and live Storage acceptance still need device checks.

## Test deployment

Apply `20261025232255_profile_photo_gallery.sql` after the existing migrations. Deploy `discovery`, `messaging`, and `delete-account` with JWT verification enabled before distributing the new client. The migration expands storage policies while preserving both legacy and signup consent. It adds no profile columns, public bucket, paid image service, or new table. Follow [migration ordering](catalog-migrations.md) and inspect a dry run before pushing; the original project's historical migration mapping differs from the test project.

## Validation and device acceptance

Package tests cover the three-photo cap, malformed/oversized images, crop bounds, draft replacement/removal/promotion, retry, obsolete-slot cleanup, and decoding old/new profile responses. SQL checks cover consent, ownership, allowed keys, service-only metadata, and unpublished extras during review. Handler checks cover path/URL validation, signatures, public projection, and deletion ordering. Simulator journeys exercise real crop gestures/JPEG export, cancelling a crop, gallery cycling, fixed frame size, and saving individual removal.

1. On an iPhone, add three differently shaped images. Crop/zoom/pan each; save and confirm the editor closes. A fourth cannot be added.
2. Relaunch and check all three owner photos. View the account from a second device in Discovery and a conversation's profile; verify dots and tap cycling, plus the first photo in avatars.
3. Remove the first photo and save. Confirm the next becomes main, only two dots remain, and deleted slots do not reappear after refresh.
4. Cancel a picker/crop/editor; stored photos must remain unchanged. Disconnect mid-save, retry, and verify all slots restore.
5. Remove all photos and check the empty state. Delete a disposable account and verify all profile photos and any selfie are removed.
6. Test portrait/landscape source orientation and inspect saved JPEG metadata. Review-on testing uses a development project and does not establish face verification.

## Hosted status — October 7, 2026 (Arizona)

The private bucket, consent table, and policies are applied to project `pnlpdevgwenkkoqjgcui`. The CLI-created migration file was renamed to match the assigned hosted version `20261007201242`; its SQL is unchanged. Account-deletion function version 2 includes photo cleanup with JWT verification enabled. An unauthenticated live request still returns 401.

Hosted rollback-only policy verification uses temporary identities and metadata; it does not upload image bytes. Supabase blocks direct Storage SQL deletion even when no rows are visible. Hosted verification therefore checks cross-user updates instead of DELETE and leaves all metadata cleanup to transaction rollback; owner deletion is covered by local RLS tests and must be confirmed through the actual Storage API on a device. No test images are retained.

Security advisors report the pre-existing RLS helper execution-grant findings ([anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)) and disabled [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). The app uses email codes rather than passwords. No new missing-RLS finding was reported for this migration; the existing findings remain unresolved.

## Test gallery deployment — October 25, 2026

Migration `20261025232255` and version 3 of `discovery`, `messaging`, and `delete-account` are deployed to `newtotown-test` (`acmrnolvakubxnaxwpzt`), with JWT verification enabled. Production was not changed. Authenticated acceptance with disposable test accounts verified three ordered, downloadable private JPEGs in Discovery and conversation profiles; missing slots reduce the gallery on refresh. Cross-account selfie reads, client metadata-RPC access, and a fourth profile upload were rejected. The deployed deletion function removed all four paths and Auth accounts; admin folder listings were empty afterward. No email/SMS was sent and existing seed accounts were unchanged.

The photo editor's Save photos action spans the content width with a large
control size and the shared 16-point text-control corner radius. Visibility,
disabled state, upload behavior, and successful-save dismissal stay unchanged.
