# Scottsdale discovery and connections

## User flow

Save profile details and a profile photo, then open the **Discovery** tab. Tap **Join discovery** to share the first name, job, activity summary, and profile photo. The sharing terms are included in [first signup](onboarding-agreement.md); joining has no repeated agreement checkbox. Profiles start hidden, including existing accounts. Birthday, email, selfie, and moderation fields are never in discovery cards.

Tap **check** to connect or **X** to pass. A connection appears only when both people choose connect. Decisions are immutable in this pilot; there is no undo or unmatch yet. Connections are derived from the two decisions, so simultaneous checks cannot create duplicate matches. Repeating the same decision after a lost response is safe.

**Profile → Settings → Hide my profile** removes the person from new discovery and connections while hidden. **Block** removes both directions from discovery and connections, even if already matched. Blocking has no client undo in this increment. Refresh reloads current eligibility and photo links; returning from the background also refreshes.

## Structure

- `App/Features/Profile`: saved-profile home with Profile/Discovery/Settings tabs; visibility, sign-out, and deletion controls live in Settings.
- `App/Features/Discovery`: screen and shared profile card; photos use the existing `brandPhotoStyle()`.
- `NewToTownCore/Discovery`: public projection, feed, service interface, and observable workflow state.
- `NewToTownSupabase/Discovery`: typed calls through the existing shared SDK client/session.
- `supabase/functions/discovery`: Auth/command handler plus public profile projection and photo-link delivery in `photos.ts`.
- `supabase/migrations/*_scottsdale_discovery.sql`: visibility consent, immutable decisions, blocks, eligibility helpers, and bounded feed queries.

Views construct no backend clients or queries. Discovery state belongs to its screen; signup does not own candidate cards. On a failed action, cached cards are discarded until refresh so an uncertain hide/block/authorization change does not keep presenting them.

## Authorization and photo delivery

The Edge Function requires gateway JWT verification and independently resolves the user through Auth. Request bodies cannot provide a caller identity or a Storage path. Only the server role can execute feed/mutation RPCs. Clients can read their own outgoing decisions, blocks, and visibility settings through RLS, but cannot write them directly or inspect incoming one-sided interest.

`private.photo_eligibility` is the shared review/moderation check used by both the existing self-only flag function and server discovery. Its authenticated invoker calls remain limited by owner RLS. Server-only discovery additionally requires visibility consent for both parties and excludes a block in either direction. Review remains off by default; enabling it requires approval of both current photo versions. Suspension and rejection apply in either mode.

The server explicitly projects public fields and signs only `<candidate UUID>/profile.jpg` paths from the authorized feed. The private bucket and owner-only Storage policies are unchanged. No selfie path is signed. URL responses use `Cache-Control: no-store`; photo links expire after **60 seconds**. A previously issued link or downloaded image cannot be instantly revoked by hiding/blocking—new requests enforce the updated state. The app offers Refresh when a photo link expires.

The existing `discovery-v1` visibility receipt records a server timestamp when joining/rejoining; it records the explicit sharing choice, rather than a new terms acceptance. Hiding without joining creates no consent row. Profile edits and profile-photo replacements are reflected to other eligible members while visible; when review is required, replacing an approved photo makes it ineligible until approved again. Deleting an account cascades its visibility, decisions, and blocks; existing deletion cleanup still removes both photo keys.

## Deployment and validation

Apply `20261010201702_scottsdale_discovery.sql` once, then deploy `discovery` with `index.ts`, `handler.ts`, and `photos.ts`, keeping JWT verification enabled. Default settings do not publish existing profiles. No new secret belongs in the app. Earlier local/hosted profile-migration versions remain mismatched; see [photo deployment notes](private-photos.md) before CLI migration deployment.

Tests cover visibility choices, current-card decisions, failed-action recovery, mutual versus one-sided connections, passes, retry idempotency, hidden/restricted/review-required profiles, block filtering, deleted-account cleanup, direct-write denial, and caller impersonation. Handler tests check public projection and profile-only signing. SQL tests use transaction-only metadata fixtures; they do not upload files or sign real photo URLs.

Phone acceptance with two real volunteer accounts:

1. Save each profile and profile photo. Open the Discovery tab without joining; neither should appear to the other.
2. Both tap **Join discovery**. Confirm only the public fields and profile photo appear, with rounded corners/shadows.
3. Check from the first account; no connection yet. Check back from the second; both Connections lists show the match after refresh.
4. Use a third volunteer to test pass, and confirm it disappears from that account's deck without a match.
5. Open **Settings** on one account and tap **Hide my profile**; refresh the other and confirm the connection disappears. Rejoin and refresh.
6. Block a connection and verify both directions disappear. Disconnect during a decision, then refresh to reconcile the saved result.
7. Wait over a minute before loading an unviewed photo; Refresh must recover expired links. Delete a disposable account and confirm profile/photo/discovery data disappear.

## Limits and rollout

This increment is for the controlled pilot, not the public launch. Messaging, reports/moderation handling, unmatch/unblock, and support/privacy materials are still needed before opening the platform broadly. No proximity/GPS or fake demo profiles are introduced. The feed returns up to 20 new candidates and 50 connections; connection pagination is follow-up work. The reviewer queue and automatic selfie retention remain separate; keep review off until they ship.

## Hosted status — October 10, 2026 (Arizona)

The migration is deployed to project `pnlpdevgwenkkoqjgcui`, and its local filename matches the hosted version. The `discovery` function version 2 is deployed with JWT verification. Review remains off. Hosted discovery and photo-review SQL suites pass in rollback-only transactions with no retained temporary users or metadata; an unauthenticated live endpoint request returns 401. Signed-photo HTTP delivery and the complete two-account journey still require device acceptance.

Security advisors show no new findings. Existing RLS-helper [anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) and [authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) execution-grant findings and disabled [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) are unchanged.
