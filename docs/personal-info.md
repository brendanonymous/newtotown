# Personal info

Open **Profile → Settings → Account → Personal info** to see the current account’s private email and phone number. Missing contacts show **Not provided** and an **Add email** or **Add phone number** action. Existing contacts remain read-only. Contact details never appear on public profiles, Discovery cards, or in application logs.

## Adding a contact

Enter the missing contact, request a code, then enter the latest code to verify it. Email is trimmed and lowercased; phone numbers use the same international normalization as sign-in. Verification accepts the configured 6–10 digit codes, including iOS code autofill. Resends have a 60-second local cooldown, with provider rate limits also enforced. Failures preserve the pending destination for retry. A contact belonging to another account cannot be added; this flow does not create or merge accounts.

Auth owns contact storage. No profile column, database migration, or Edge Function deployment is needed. After verification the adapter fetches the original owner’s fresh Auth record and checks the destination and confirmation timestamp before dismissing and refreshing Personal info.

## Structure and account isolation

- `App/Features/Profile/PersonalInfoView.swift`: contact rows and navigation.
- `App/Features/Profile/ContactDetailsView.swift`: request, verification, resend, and retry UI.
- `Sources/NewToTownCore/Account/ContactDetailsService.swift`: normalized destination and service contract.
- `Sources/NewToTownCore/Account/ContactDetailsModel.swift`: transient verification state and cooldown.
- `Sources/NewToTownSupabase/Account/SupabaseContactDetailsService.swift`: account-bound Auth transport.

Views receive service interfaces; they do not construct clients. The write adapter captures the owner’s bearer token and checks the shared session identity before and after each request. It uses Auth’s `PUT /user`, `POST /resend`, and `POST /verify` with `email_change` or `phone_change`. It never passes administrative confirmation flags or installs a verification response’s session into the shared SDK client. That prevents a late response from replacing a different account’s session after sign-out/switch. The existing SDK session retains normal persistence and refresh responsibilities; this screen reads fresh Auth data rather than cached user fields.

The models discard cancelled/reset requests. Pull-to-refresh keeps loaded contacts visible while fetching. Failures clear unverified contact display and offer retry; interrupted refreshes retain previously loaded details. Returning to the signed-in shell with a new account creates fresh feature state.

## Provider setup

SMS uses the existing Supabase Phone provider and Twilio Verify setup. Email uses the existing Supabase SMTP/Resend setup. In **Supabase → Authentication → Emails → Change email address**, ensure the email body includes `{{ .Token }}` so the user receives a numeric code. Changing only Confirm signup and Magic link does not update the Email Change template. Keep Secure email change enabled; replacing an existing email is outside this flow.

See the official [update-user API](https://supabase.com/docs/reference/swift/auth-updateuser), [verification types](https://supabase.com/docs/reference/swift/auth-verifyotp), and [email templates](https://supabase.com/docs/guides/auth/auth-email-templates). No Resend DNS changes are required for the already verified sending domain.

## Validation and device acceptance

Package tests cover normalization, invalid input, resend cooldown, retry, late model responses, strict request bodies, confirmation timestamps, duplicate contacts, rate limits, and account switches during verification. Offline simulator journeys cover both adding email to a phone account and adding phone to an email account, including wrong-code retry. Fixtures never send messages and are compiled out of release builds.

Real provider delivery still needs acceptance on an iPhone:

1. In the test app, add a missing email to a phone account. Check the latest email contains a code, a wrong code fails, and the correct code returns to the same account’s Personal info.
2. Add a missing phone to an email account. Confirm SMS delivery, verification, preservation of the original email, and no duplicate profile.
3. Sign out and sign in using the newly added contact. Confirm the same profile, interests, connections, and messages remain available.
4. Try an already-used contact and a disconnected network; verify clear retry behavior. Switch accounts during a pending request and confirm no contact or verification state carries over.

Discovery, Connections, Settings, and Personal info retain native iOS pull-to-refresh with vertical bouncing for short content and empty states.
