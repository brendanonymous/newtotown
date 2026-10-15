# First-time introduction and agreement

After verifying email, an account without an `onboarding-v1` receipt sees three short slides: platonic friendship, respectful behavior, and private storage/profile sharing. The final **I agree — keep it platonic** action also confirms the age requirement. No profile form, photo upload, or discovery screen repeats an agreement checkbox.

Acceptance is stored before creating a profile. Sign-out, app reinstall, another device, profile edits, photo replacement/removal, and hiding/rejoining discovery do not reset it. Closing the app before acceptance resumes the introduction; a failed write stays on that step and can be retried. If the receipt saved but profile loading failed, retry is idempotent. Deleting an account cascades the receipt; a new account starts again.

Existing pilot accounts without this consolidated receipt see it once on their next account restore. No previous acceptance is backfilled or represented as accepting new terms. Existing photo-consent rows are retained for compatibility with older pilot clients.

## Code and storage

- `App/Features/Onboarding/FirstSignupIntroduction.swift`: exact displayed terms, page navigation, and acceptance action.
- `NewToTownCore/Onboarding`: durable-state check and onboarding transitions behind `OnboardingService`.
- `NewToTownSupabase/Onboarding/SupabaseOnboardingService.swift`: owner-scoped receipt read and idempotent insert.
- `supabase/migrations/*_account_agreements.sql`: owner-only RLS, fixed version, immutable server timestamp, and photo policy updates.

The receipt contains only user ID, `onboarding-v1`, and server acceptance time. Clients cannot change its timestamp, delete it, or accept on another account's behalf. New photo uploads require this receipt (or the earlier photo consent) and an existing profile. Account-wide acceptance does not publish a profile: **Join discovery** remains an explicit choice, with **Hide my profile** available afterwards. Camera permissions still come from iOS.

Preserve this version's meaning when editing its terms. Materially different collection or sharing requires a new version and an explicit migration plan. The slides are the pilot agreement UI; comprehensive public privacy/support materials remain part of launch preparation.

## Validation

Core tests cover first verification, blocked profile saves before acceptance, failure/retry, interruption, accepted-but-incomplete signup, returning login, photo replacement, and join/hide without repeated consent. SQL tests cover owner isolation, acceptance before a profile, immutable receipts, unknown versions, photo upload/replacement with only the new receipt, denial without consent, and deletion cascades. Existing photo-policy tests continue covering old receipts.

Phone acceptance: create a disposable account, verify email, read/swipe all slides and accept. Complete the profile, upload and replace its photo, and join/hide/rejoin discovery. No repeated checkbox should appear. Sign out and back in and restart the app; the introduction should not return. Repeat signup with another disposable account, close before acceptance, and confirm the introduction resumes.

## Hosted status — October 10, 2026

Migration `20261010220601_account_agreements.sql` is deployed to project `pnlpdevgwenkkoqjgcui`; the local filename matches the hosted version. Hosted rollback-only tests pass without retaining test users, receipts, or Storage metadata. No existing account has been marked accepted. Security advisors show no new findings; the pre-existing findings remain listed in [discovery](discovery.md).
