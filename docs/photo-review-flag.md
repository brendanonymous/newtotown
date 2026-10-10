# Photo review feature flag

## Behavior

`public.pilot_features.photo_review_required` is the single server-owned pilot switch. It starts **false**. Authenticated clients may read it, but only trusted server/database operators may change it. No local override or third-party flag service is used.

| Mode | Photo screen | Discovery eligibility prerequisite |
| --- | --- | --- |
| Off | Profile photo; no selfie capture | Saved profile and profile photo |
| On | Profile photo and private selfie | Both exact photo versions approved by a trusted reviewer |
| Missing/unavailable | Loading/retry; uploads stop | Ineligible when the configuration row is missing |

Suspended or rejected profiles are ineligible in both modes. Neither mode grants access to another user's photos. There are no verified badges. Selfie capture and manual photo comparison cannot establish legal identity, age, intentions, or sexual orientation.

## Code boundaries

- `NewToTownCore/Photos/PhotoRequirements.swift`: typed requirements, independent of SwiftUI and Supabase.
- `PhotoSubmissionModel`: refreshes requirements on load/save, validates required images, and refreshes requirements when the mode changes while open. A changed mode requires checking the updated photo requirements before retrying; consent remains the account-level agreement.
- `PhotoSubmissionView`: renders controls for the current requirements; agreement copy lives in first-time onboarding.
- `SupabasePhotoService`: reads the server flag, revalidates immediately before uploads, and uploads no selfie when review is off.
- `supabase/migrations/*_photo_review_flag.sql`: configuration permissions, trusted moderation state, and a self-only eligibility function.

The existing photo-service boundary is reused; no global mutable flag store, environment checks, or generic configuration framework is added. The flag is refreshed on screen entry and save, rather than pushed live. If it changes again during an upload, backend eligibility still evaluates the current mode.

## Server eligibility

`public.is_own_profile_discoverable()` is a security-invoker function with no user-ID parameter; it checks photo eligibility separately from the separate discovery visibility choice. It evaluates the caller's profile through existing RLS. `profile_access` is owner-readable and client-read-only; operators own suspension, rejection, and approval fields. No access row means no approval and no moderation restriction.

An approval records both Storage object IDs and `updated_at` values. Replacing either file makes the recorded version stale; removing/recreating a file cannot reuse the old object ID. Review-off mode does not create an approval. Turning review on therefore makes previously unreviewed users ineligible until reviewed. Turning it off never bypasses suspension or rejection.

The [discovery feature](discovery.md) now reuses `private.photo_eligibility` behind this self-only function. Server discovery enforces eligibility for both caller and candidates, visibility choice, and pairwise blocks. Profile photos are delivered through authorized short-lived links; private profile rows and the bucket remain owner-only.

## Operation

Apply the new migration once before running this app version. Its default is review off. Existing app versions still show their original selfie controls; the flag does not remotely rewrite old binaries.

Inspect or change the setting in the Supabase SQL editor as a trusted operator:

```sql
select photo_review_required from public.pilot_features where id = true;

-- Closed pilot: profile photo only.
update public.pilot_features set photo_review_required = false where id = true;
```

Do not enable review for the pilot until the reviewer workflow, review-version audit trail, and automatic selfie retention cleanup ship. The required-mode path can be tested in a development project with `true`; no approvals are automatically granted. This PR reserves approval fields and validates their semantics, but supplies no reviewer queue or approval UI.

Existing selfies remain private until users remove photos or delete their account; toggling the flag is not a deletion operation. Saving a profile while review is off does not upload or replace a selfie. The existing remove action deletes both permitted keys, including a selfie uploaded by an earlier version. Automatic retention remains separate work before new external selfie collection.

## Validation

Swift tests cover both modes, profile-only restore, missing/invalid/oversized photos, unavailable flags, and requirement refresh when enabling or disabling review during a session. PostgreSQL tests cover client-write denial, anonymous/cross-user isolation, eligibility in both modes, suspension/rejection, stale approvals for either image, recreated objects, missing configuration, and deleted accounts.

Phone checks: with review off, open **My photos**, confirm there is no selfie control, save only a profile photo, and reopen to restore it. Remove photos and confirm an old selfie is also removed. In a development project, enable review while the screen is open, press save, and confirm the updated requirements require a selfie without another agreement. No successful upload should display a verified badge.

## Hosted status — October 8, 2026 (Arizona)

Migration `20261009021759_photo_review_flag.sql` is applied to project `pnlpdevgwenkkoqjgcui`, with review **off**. Its local filename matches the hosted migration version. The earlier profile migration still has a local/hosted version mismatch; see [photo deployment notes](private-photos.md) before using CLI deployment.

The full new SQL test passes locally and on hosted Supabase in a rollback-only transaction. Hosted fixtures use explicit Auth column names and seed earlier Storage timestamps so the hosted `updated_at = now()` trigger can represent a subsequent replacement within one transaction. No test users, metadata, or uploaded files remain. The iOS simulator build and 26 Swift tests pass; physical-device acceptance remains pending.

Security advisors show no new findings. Existing RLS-helper [anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) and [authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) execution-grant findings, and disabled [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection), are unchanged. This app uses email codes.
