# Private photo upload and selfie capture

## Scope

After saving a profile, open **My photos**, choose a profile image, and save. Storage consent is recorded once during [first signup](onboarding-agreement.md). The server-controlled [photo-review flag](photo-review-flag.md) defaults off; selfie capture is shown and required only when review is on. Storage remains private; opting into discovery permits eligible members to view the profile photo only. Selfies remain owner-only. A successful save means the required uploads completed; it does not approve or verify the person. Manual review and reviewer access remain separate work. [Discovery](discovery.md) shares only opted-in profile photos through authorized links; selfies remain private.

The picker imports images without broad photo-library access. The camera requests permission only on **Take selfie**, prefers the front camera, and supports cancel, denied permission/settings recovery, and unavailable-camera feedback. Imported images are downsampled to 1,200 pixels; both sources are drawn into a fresh image and encoded as JPEG, omitting original EXIF/GPS metadata. Each upload is limited to 3 MiB. Capture is enforced by the app UI, not proof of liveness or identity; a modified client can supply another file.

## Structure

- `App/Features/Photos`: feature view, camera bridge, pixel normalization.
- `App/DesignSystem/BrandPhotoStyle.swift`: shared rounded corners and subtle shadow for photo previews; use `brandPhotoStyle()` for future photo surfaces.
- `Sources/NewToTownCore/Photos`: photo data validation, workflow state, service interface.
- `Sources/NewToTownSupabase/Photos`: authenticated Storage operations; consent persistence belongs to onboarding.
- `SupabaseServices`: constructs one SDK client shared by onboarding and photos.

The photo model belongs to its presented screen; onboarding does not own photo buffers or workflow transitions. Views contain no backend queries. No additional image or face-recognition dependencies are introduced.

## Storage and consent

The private `private-photos` bucket permits JPEG uploads up to 3 MiB. Storage policies restrict reads/writes to `<auth.uid()>/profile.jpg` and `<auth.uid()>/selfie.jpg`. Uploads also require an existing private profile and an `onboarding-v1` account agreement or a retained `pilot-v1` photo-consent record. Consent uses a server timestamp and owner-only access; clients cannot change the timestamp. The record is the first acceptance of this consent version, not a per-image review audit. The app does not ask for agreement again when an image changes.

When review is on, two uploads are not transactional. If one succeeds and the other fails, the screen retains the selected data and offers retry; retries overwrite the same two owner-scoped keys. Reopening downloads the files that exist, including partial saves. Successful removal clears both remotely and locally. On an uncertain removal result, local selections remain with a retry message. Unsaved local selections are discarded when the screen closes.

Users can remove their photos and delete their account. Account deletion removes both permitted keys through the Storage API before deleting Auth, then cascades the profile and consent record. Cleanup failure stops Auth deletion. A deleted identity cannot upload again because Storage insertion requires an existing profile and consent. Do not delete Storage metadata directly with SQL; actual file cleanup uses the Storage API.

This internal pilot has no automatic selfie expiry yet. Before external photo collection, agree on the reviewer and a retention/deletion deadline, implement automated cleanup, and publish the consent/privacy text. Before approval is implemented, replace these mutable draft keys with versioned review submissions so changing an approved photo cannot retain approval. These draft uploads do not enter a review queue or become discoverable.

## Deployment and validation

Apply `20261007201242_private_photos.sql` once, then deploy the updated `delete-account` function including `photos.ts`, with JWT verification enabled. Deploy cleanup before distributing the upload-capable app. The earlier profile migration has hosted version `20261001042036` and local filename `202609080001_private_profiles.sql`; reconcile that earlier mapping before adopting CLI deployment. Do not blindly reapply every local migration to the existing project.

Swift tests cover one-time onboarding acceptance, missing/invalid/oversized files, restore, replacement, save retry, and removal recovery. Handler tests cover cleanup ordering, owner-scoped paths, and cleanup failure. Local PostgreSQL tests check bucket settings, consent permissions, owner operations, cross-user isolation, allowed paths, anonymous access, and deleted identities. The fixture tests metadata/RLS; it does not emulate Storage HTTP uploads or camera hardware.

Device acceptance (selfie steps require review enabled in a development project; the pilot defaults off):

1. Sign in and save a profile. Open **My photos**. Cancel the picker and camera; neither should upload anything.
2. Choose a profile photo and capture a selfie. Check previews/orientation, centered photo controls, rounded corners, and subtle shadows. Confirm **Save photo** has readable light text and the save, saved-message, and removal controls are centered. Save without another agreement; the screen should close after a successful upload and stay open on failure.
3. Close/reopen the screen and relaunch the app. Both private photos should restore. On the saved-profile screen, the add-photo prompt should stay hidden while a profile photo exists.
4. Replace one image and save without another agreement. Disconnect during upload; retry and verify that both files restore correctly.
5. Remove both photos and reopen. Both should be absent; after dismissing My photos, the add-photo prompt should return. Re-upload with a disposable account, delete that account, and confirm both Storage files are removed.
6. Deny camera access and test the settings link. Simulator capture must show the unavailable-camera message.

Hosted authenticated Storage HTTP behavior, image metadata inspection, actual camera capture, and deletion with photos require these device checks before acceptance. Automated checks do not establish successful face verification.

## Hosted status — October 7, 2026 (Arizona)

The private bucket, consent table, and policies are applied to project `pnlpdevgwenkkoqjgcui`. The CLI-created migration file was renamed to match the assigned hosted version `20261007201242`; its SQL is unchanged. Account-deletion function version 2 includes photo cleanup with JWT verification enabled. An unauthenticated live request still returns 401.

Hosted rollback-only policy verification uses temporary identities and metadata; it does not upload image bytes. Supabase blocks direct Storage SQL deletion even when no rows are visible. Hosted verification therefore checks cross-user updates instead of DELETE and leaves all metadata cleanup to transaction rollback; owner deletion is covered by local RLS tests and must be confirmed through the actual Storage API on a device. No test images are retained.

Security advisors report the pre-existing RLS helper execution-grant findings ([anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)) and disabled [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). The app uses email codes rather than passwords. No new missing-RLS finding was reported for this migration; the existing findings remain unresolved.
