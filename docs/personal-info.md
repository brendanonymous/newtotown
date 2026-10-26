# Personal info

Open **Profile → Settings → Account → Personal info** to see the current account’s private email and phone number. Missing contacts show **Not provided** and an **Add email** or **Add phone number** action. Existing contacts remain read-only. Contact details never appear on public profiles, Discovery cards, or in application logs.

## Adding a contact

For email, request a verification email and open its link on the iPhone where NewToTown is installed. Supabase verifies the link, then redirects to the app. The app reads the signed-in owner’s fresh Auth record before showing **Email verified successfully**. The pending editor also checks that the confirmed email matches the requested destination before returning to Personal info. A numeric code remains available as a fallback (including when opening email on another device). Phone numbers continue to use SMS codes. Email is trimmed and lowercased; phone numbers use the same international normalization as sign-in. Verification accepts the configured 6–10 digit codes, including iOS code autofill. Resends have a 60-second local cooldown, with provider rate limits also enforced. Failures preserve the pending destination for retry. A contact belonging to another account cannot be added; this flow does not create or merge accounts.

Auth owns contact storage. No profile column, database migration, or Edge Function deployment is needed. After verification the adapter fetches the original owner’s fresh Auth record and checks the destination and confirmation timestamp before dismissing and refreshing Personal info.

## Structure and account isolation

- `App/Features/Profile/PersonalInfoView.swift`: contact rows and navigation.
- `App/Features/Profile/ContactDetailsView.swift`: request, verification, resend, and retry UI.
- `App/Features/Profile/EmailVerificationResultView.swift`: app-wide callback routing and verified/error result.
- `Sources/NewToTownCore/Account/EmailVerificationCallback.swift`: exact callback route and error parsing.
- `Sources/NewToTownCore/Account/ContactDetailsService.swift`: normalized destination and service contract.
- `Sources/NewToTownCore/Account/ContactDetailsModel.swift`: transient verification state and cooldown.
- `Sources/NewToTownSupabase/Account/SupabaseContactDetailsService.swift`: account-bound Auth transport.

Views receive service interfaces; they do not construct clients. The write adapter captures the owner’s bearer token and checks the shared session identity before and after each request. It uses Auth’s `PUT /user`, `POST /resend`, and `POST /verify` with `email_change` or `phone_change`. It never passes administrative confirmation flags or installs a verification response’s session into the shared SDK client. That prevents a late response from replacing a different account’s session after sign-out/switch. The existing SDK session retains normal persistence and refresh responsibilities; this screen reads fresh Auth data rather than cached user fields.

The models discard cancelled/reset requests. Pull-to-refresh keeps loaded contacts visible while fetching. Failures clear unverified contact display and offer retry; interrupted refreshes retain previously loaded details. Returning to the signed-in shell with a new account creates fresh feature state.

## Provider setup

SMS uses the existing Supabase Phone provider and Twilio Verify setup. Email uses the existing Supabase SMTP/Resend setup; no DNS changes or new website are required.

Configure **each project separately** in Supabase → Authentication → URL Configuration:

| Project | Site URL and Redirect URLs entry |
| --- | --- |
| `newtotown-test` (`acmrnolvakubxnaxwpzt`) | `com.newtotown.ios.test://auth/email-verified` |
| Production (`pnlpdevgwenkkoqjgcui`) | `com.newtotown.ios://auth/email-verified` |

Add the exact URL to **Redirect URLs** (no wildcard). For this iOS-only app, set **Site URL** to the same URL to replace the localhost default. The app explicitly supplies the redirect on both email update and resend; changing Site URL alone does not register an allowed redirect. Preserve any other URLs still in use. Install a build containing the callback support before requesting a new email; older emails retain their original redirect.

In **Authentication → Emails → Change email address**, set the subject to `Verify your NewToTown email` and use:

```html
<p>Confirm this email for your NewToTown account.</p>
<p><a href="{{ .ConfirmationURL }}">Verify email</a></p>
<p>Or enter this code in the app: {{ .Token }}</p>
```

Use the complete `ConfirmationURL` variable, not a link directly to SiteURL, RedirectTo, or localhost: Supabase must verify the one-time token first. Leave Secure email change enabled. Confirm signup and Magic link templates used for sign-in can keep their existing numeric-code bodies.

The URL scheme comes from `PRODUCT_BUNDLE_IDENTIFIER`, so the two installed apps register different callbacks. The app accepts only its exact `auth/email-verified` route, handles error redirects, and never logs URLs or adopts callback access/refresh tokens. A forged callback cannot confirm an email or sign in: success requires the existing account’s server-confirmed email. A signed-out callback asks the user to sign in and check Personal info; it does not sign them in from the link. A cold launch waits for session restoration before checking. This flow adds missing email only; it does not replace existing contacts.

Dashboard settings and email templates are operational configuration, not SQL migrations; they are not deployed by merging this PR. No Auth dashboard changes were made by the code update.

Official references: [mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), [redirect configuration](https://supabase.com/docs/guides/auth/redirect-urls), [email templates](https://supabase.com/docs/guides/auth/auth-email-templates).

## Validation and device acceptance

Package tests cover normalization, invalid input, resend cooldown, retry, late model responses, strict request bodies, confirmation timestamps, duplicate contacts, rate limits, and account switches during verification. Offline simulator journeys cover both adding email to a phone account and adding phone to an email account, including wrong-code retry. Fixtures never send messages and are compiled out of release builds.

Real provider delivery still needs acceptance on an iPhone:

1. In the test app, add a missing email to a phone account. Open the latest email link on the same iPhone. Confirm the app opens, shows success, and Personal info reflects the email. Repeat with the app terminated to check cold launch. Verify the code fallback and wrong-code retry too.
2. Add a missing phone to an email account. Confirm SMS delivery, verification, preservation of the original email, and no duplicate profile.
3. Sign out and sign in using the newly added contact. Confirm the same profile, interests, connections, and messages remain available.
4. Retry an expired/used link: show an error rather than claiming success. Open a test link with both apps installed and confirm only NewToTown Test opens. Open a link while signed out; confirm it never creates a session.
5. Try an already-used contact and a disconnected network; verify clear retry behavior. Switch accounts during a pending request and confirm no contact or verification state carries over.

Discovery, Connections, Settings, and Personal info retain native iOS pull-to-refresh with vertical bouncing for short content and empty states.
