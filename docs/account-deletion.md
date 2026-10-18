# Account deletion

## App flow

Signed-in users can choose **Delete account** from the profile form, saved profile, or account-recovery screen. A destructive confirmation explains permanence; Cancel makes no request. During deletion, other actions and sheet dismissal are disabled. Success clears the profile draft, email, resend cooldown, and device session, returning to email entry. Failure keeps the current screen and draft with recovery guidance.

The onboarding service owns deletion while account management is the only signed-in feature. No generic account repository or extra session model is needed yet. Saved-profile account controls now live in Settings; signup and recovery retain their account actions. Extract signed-in composition from onboarding as messaging is introduced; see the [code structure review](code-structure-review.md).

## Server boundary

`supabase/functions/delete-account/index.ts` reads server-managed credentials and starts the handler. `handler.ts` accepts POST only and performs these steps in order:

1. Resolve the Bearer token through Supabase Auth `/user`. Do not trust decoded claims or a supplied user ID.
2. Revoke all refresh sessions for that token's account.
3. Remove both permitted private photo keys through Storage. Cleanup failure stops deletion.
4. Hard-delete only the verified Auth user with the server-side admin credential. The existing profile foreign key cascades deletion.
5. Return 204 after Auth confirms deletion. The iOS service clears its SDK/Keychain session.

Gateway JWT verification stays enabled in `supabase/config.toml`. The handler also validates callers independently. No server credential enters the app. Responses and logs must not expose tokens or upstream error bodies. The function has no third-party runtime dependencies.

Auth deletion does not retroactively invalidate every issued access JWT. The existing profile foreign key prevents a deleted identity from recreating a private profile; tests cover that case. Future media, discovery, and messaging permissions must account for deleted identities too.

## Deployment and verification

Deploy the reviewed `delete-account` function with JWT verification enabled, using the versioned `index.ts`, `handler.ts`, `photos.ts`, and `_shared/auth.ts`/`_shared/http.ts` dependencies. Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in its hosted function environment. No schema migration is required. Deploy the function before testing this app branch on a phone.

Run:

```sh
swift test
deno check supabase/functions/delete-account/index.ts
deno test supabase/functions/delete-account/handler_test.ts
```

The handler tests inject a fake HTTP transport, make no live requests, and cover absent/invalid authentication, caller-selected targets, session revocation failures, deletion failures, and sanitized network errors. PostgreSQL tests cover profile cascade, isolation of another profile, and rejected recreation using a deleted identity. CI runs these alongside the iOS build and signup UI smoke test.

Use a disposable email/account for device acceptance. Save a profile, cancel deletion and confirm it remains; then confirm deletion, relaunch, and verify the profile is gone. Signing up again must create a fresh account. Try offline deletion and verify the app preserves the draft with recovery guidance. Do not use an account whose profile you want to keep.

## Hosted status — October 7, 2026 (Arizona)

Function version 2 (including private-photo cleanup) is deployed to project `pnlpdevgwenkkoqjgcui` with gateway JWT verification enabled. Deployment uses the source in this PR. Live POST requests with missing or malformed credentials returned HTTP 401. No real account was deleted during these checks. Authenticated end-to-end deletion still requires a disposable test account on a device; the server's happy path is covered with mocked Auth responses and real local database cascade tests.

## Failure behavior and scope

Revocation and Auth deletion are separate operations. If revocation succeeds but deletion fails, the account may remain with its sessions revoked; signing in again provides a fresh session for retry. A lost response after successful deletion is ambiguous to the client: it preserves the draft until the user retries or signs out and checks the account. Do not display a deletion-success message on an unconfirmed result.

This version deletes private photos, active Auth records, the private profile, photo consent, account-level onboarding acceptance, discovery settings, outgoing/incoming connection decisions, and blocks. Provider backups/logs follow their own retention settings. The private-photos bucket is now included in cleanup. Connections are derived from decisions, so they have no separate row to delete. The [messaging backend](messaging.md) adds cascade deletion of the entire conversation and all messages when either participant is deleted. The messaging migration is deployed; deleting either participant removes that thread and all its messages. Extend server cleanup before introducing those resources; Supabase cannot delete an Auth user who still owns Storage objects. This endpoint is not a complete future data-retention implementation.
