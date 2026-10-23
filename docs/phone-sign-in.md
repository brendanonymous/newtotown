# Phone sign-in

The phone-sign-in PR makes text codes the new-account path. Supabase still owns authentication, OTP verification, session persistence, profiles, database, and storage. The app uses the already pinned Supabase Swift SDK, with no SMS vendor SDK or credentials in the bundle. No profile-schema change or new Edge Function is needed.

## Before distributing this PR

1. Twilio Verify was selected October 22. It is supported by [Supabase phone authentication](https://supabase.com/docs/guides/auth/phone-login). Supabase requires this integration; [Resend](https://resend.com/features/email-api) continues delivering email and does not replace SMS delivery. Account creation and hosted credentials are still pending; this PR does not purchase or configure the service.
2. In Supabase → Authentication → Sign In / Providers → Phone, enable Phone and enter the chosen provider's credentials in the dashboard. Enable phone signup and confirmation. Keep Email enabled for existing accounts. Leave the working Resend SMTP and numeric email-code templates in place.
3. Create a Twilio Verify service named `newtotown`, then configure Supabase's **Twilio Verify** option with the account SID, Auth token, and Verify service SID. The Verify SID starts with `VA`; do not substitute a Programmable Messaging service SID. Keep credentials out of Git, app configuration, logs, and chat. Twilio trial accounts require approved/verified recipient numbers; see the [trial guide](https://www.twilio.com/docs/usage/trials/try-out-verify).
4. Before inviting testers, configure Supabase Auth SMS rate limits and the provider's geographic permissions, fraud protections, and spending alerts. Start with US destinations for this pilot. The client's 60-second resend timer is a UX aid; server/provider controls enforce limits. Wider public signup should include a reviewed CAPTCHA integration and monitoring.
5. Test delivery and verification on two authorized real phones, then distribute through TestFlight. Local tests never send real texts. Do not configure fixed test codes on the shared pilot; use an isolated development project for any test-number bypass.

Twilio Verify is the selected provider; hosted setup remains pending. Its [current pricing](https://www.twilio.com/en-us/verify/pricing) lists $0.05 per successful verification plus $0.0083 per US SMS attempt (checked October 22, 2026). One successful verification with one SMS is about $0.0583 before other applicable charges; retries add SMS attempts. Confirm prices/terms in the provider account before enabling billing. Phone login does not require adding phone MFA to this app.

## Existing accounts

Existing sessions restore normally. **Already joined with email? Sign in with email** requests an email code with `shouldCreateUser: false`, preserving the same Supabase user ID and profile. New phone signups use `shouldCreateUser: true`.

An unlinked phone number does not automatically identify an existing email account. Signing up with it creates a separate account; we never merge accounts by name or an unverified contact value. The current app does not attach a phone number to an existing email account. A later authenticated, OTP-confirmed phone-link flow is required before removing email login. Keep email available until that migration is implemented and tested.

## Validation and phone checks

Phone formatting accepts US local numbers or explicit international country codes; Supabase/provider validation still determines reachability. A phone code goes through `verifyOTP(... type: .sms)`; email uses `.email`. The account identifier is captured only after a successful send and cleared on restarting sign-in or sign-out. The one-time agreement/profile flow remains shared.

Automated checks cover normalization, invalid input, resend cooldown, code channel selection, no stale-identifier verification, account cleanup, the actual SDK `/otp` and `/verify` bodies, and restored sessions. Offline simulator journeys exercise phone signup, existing-email fallback, and account switching. They do not prove carrier delivery.

On a phone after provider setup: request a text, try a wrong code, verify the correct code, complete the one-time agreement/profile, relaunch, and sign out/in. Confirm Personal info shows the authenticated phone, and that another user cannot see it. Sign into an existing email account separately and confirm its original profile remains intact. Check SMS usage in the provider dashboard after testing.
