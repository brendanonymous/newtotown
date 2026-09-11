# Backend setup and phone testing

## What this PR enables

Email code signup/sign-in → editable private profile → saved confirmation. Returning users restore their Supabase session and saved details. Sessions use the official SDK's default Apple Keychain storage and refresh handling. Signing out clears this device's local session.

Profiles contain a first name, job title, activity goal, birthday, Scottsdale location, and platonic agreement. Client validation improves feedback; the database independently enforces age, field limits, location, ownership, and agreement. Birthdays are UTC calendar dates and age is self-reported, not verified.

This PR does not implement Apple sign-in, photo upload, selfie verification, discovery, messaging, account deletion, or invitations. Use it only for internal testing until the remaining user-data and safety flows ship. Profile creation does not grant discoverability or photo approval.

## Supabase project setup

No migration or dashboard setting has been applied to the hosted project by this PR.

1. Review `supabase/migrations/202609080001_private_profiles.sql`. Run it once in the project's SQL Editor after code review, or apply through the Supabase CLI migration workflow. Do not run the test fixture in Supabase.
2. Enable the Email provider and new-user signup in Authentication settings. Keep email verification enabled.
3. Change the **Magic Link** email template to include `{{ .Token }}` as a visible numeric code. The app verifies an email OTP; it does not handle a magic-link redirect. Example body: `<p>Your newtotown sign-in code is: {{ .Token }}</p>`.
4. Supabase's default SMTP only sends to project-team addresses and has a low rate limit. Configure a custom SMTP provider and sender before testing with other people. No email provider has been selected or configured by this PR.
5. Ensure the `public` schema is exposed through the Data API. The migration supplies the table grants and RLS policies; do not grant broader write access.

References: [email OTP](https://supabase.com/docs/reference/swift/auth-signinwithotp), [SMTP restrictions](https://supabase.com/docs/guides/auth/auth-smtp), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

`Configuration/Public.xcconfig` contains only the supplied project host and publishable key. Both are public client values. Override them in ignored `Local.xcconfig` when using another project. Never add database passwords, secret keys, or service-role keys.

## Test on your iPhone

Use this PR's branch. Open the project, select your team and phone, and run. A new checkout needs its own ignored `Configuration/Local.xcconfig` signing values; your original checkout's settings have not been changed.

- Tap **Join or sign in**. An invalid email should show an error without sending mail.
- Use a permitted test email, enter its code, and confirm that an invalid code leaves you on the code screen. Resend becomes available after 60 seconds; server limits may be stricter.
- Try saving with a birthday younger than 18 or without the agreement: the profile must not save.
- Save valid details. The confirmation must say the profile is private and photo verification is coming next.
- Close and reopen signup, then terminate/relaunch the app: the saved profile should restore.
- Edit and save, then sign out. Signing in again should restore the same details.
- Disconnect networking while saving: stay on the form with the entered values and a retryable error.

Real email delivery, session refresh against the hosted project, and physical-device journeys require the dashboard setup above and have not been live-tested by the automated suite.

## Database tests

`supabase/tests/auth_fixture.sql` emulates only Supabase's auth identity function and roles in an **empty local test database**. Apply it, the migration, and `supabase/tests/profiles.sql` with `psql -v ON_ERROR_STOP=1`. CI provisions PostgreSQL 17 for this.

These tests exercise real PostgreSQL grants, RLS, upserts, age constraints, cross-user isolation, and blocked self-approval. They do not emulate Supabase's email service or JWT signature validation.
