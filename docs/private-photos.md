# Private photo upload and selfie capture

## Scope

After saving a profile, open **My photos**, choose a profile image, take a camera selfie, and accept private storage before saving. Both images remain private to the owner. A successful save means both uploads completed; it does not approve or verify the person. Manual review, reviewer access, and discovery are the next increment.

The picker imports images without broad photo-library access. The camera requests permission only on **Take selfie**, prefers the front camera, and supports cancel, denied permission/settings recovery, and unavailable-camera feedback. Imported images are downsampled to 1,200 pixels; both sources are drawn into a fresh image and encoded as JPEG, omitting original EXIF/GPS metadata. Each upload is limited to 3 MiB. Capture is enforced by the app UI, not proof of liveness or identity; a modified client can supply another file.

## Structure

- `App/Features/Photos`: feature view, camera bridge, pixel normalization.
- `Sources/NewToTownCore/Photos`: photo data validation, workflow state, service interface.
- `Sources/NewToTownSupabase/Photos`: authenticated Storage operations and consent persistence.
- `SupabaseServices`: constructs one SDK client shared by onboarding and photos.

The photo model belongs to its presented screen; onboarding does not own photo buffers or workflow transitions. Views contain no backend queries. No additional image or face-recognition dependencies are introduced.

## Storage and consent

The private `private-photos` bucket permits JPEG uploads up to 3 MiB. Storage policies restrict reads/writes to `<auth.uid()>/profile.jpg` and `<auth.uid()>/selfie.jpg`. Uploads also require an existing private profile and a `pilot-v1` consent record. Consent uses a server timestamp and owner-only access; clients cannot change the timestamp. The record is the first acceptance of this consent version, not a per-image review audit. The app asks for agreement again when an image changes.

Two uploads are not transactional. If one succeeds and the other fails, the screen retains the selected data and offers retry; retries overwrite the same two owner-scoped keys. Reopening downloads the files that exist, including partial saves. Successful removal clears both remotely and locally. On an uncertain removal result, local selections remain with a retry message. Unsaved local selections are discarded when the screen closes.

Users can remove their photos and delete their account. Account deletion removes both permitted keys through the Storage API before deleting Auth, then cascades the profile and consent record. Cleanup failure stops Auth deletion. A deleted identity cannot upload again because Storage insertion requires an existing profile and consent. Do not delete Storage metadata directly with SQL; actual file cleanup uses the Storage API.

This internal pilot has no automatic selfie expiry yet. Before external photo collection, agree on the reviewer and a retention/deletion deadline, implement automated cleanup, and publish the consent/privacy text. Before approval is implemented, replace these mutable draft keys with versioned review submissions so changing an approved photo cannot retain approval. These draft uploads do not enter a review queue or become discoverable.

## Deployment and validation

Apply `20261007195830_private_photos.sql` once, then deploy the updated `delete-account` function including `photos.ts`, with JWT verification enabled. Deploy cleanup before distributing the upload-capable app. The existing profile migration's hosted version mapping is documented in `backend-setup.md`; do not blindly reapply every local migration to the existing project.

Swift tests cover consent, missing/invalid/oversized files, restore, replacement, save retry, and removal recovery. Handler tests cover cleanup ordering, owner-scoped paths, and cleanup failure. Local PostgreSQL tests check bucket settings, consent permissions, owner operations, cross-user isolation, allowed paths, anonymous access, and deleted identities. The fixture tests metadata/RLS; it does not emulate Storage HTTP uploads or camera hardware.

Device acceptance:

1. Sign in and save a profile. Open **My photos**. Cancel the picker and camera; neither should upload anything.
2. Choose a profile photo and capture a selfie. Check previews/orientation, accept consent, and save.
3. Close/reopen the screen and relaunch the app. Both private photos should restore.
4. Replace one image, agree again, and save. Disconnect during upload; retry and verify that both files restore correctly.
5. Remove both photos and reopen. Both should be absent. Re-upload with a disposable account, delete that account, and confirm both Storage files are removed.
6. Deny camera access and test the settings link. Simulator capture must show the unavailable-camera message.

Hosted authenticated Storage HTTP behavior, image metadata inspection, actual camera capture, and deletion with photos require these device checks before acceptance. Automated checks do not establish successful face verification.
