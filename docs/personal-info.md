# Personal info

Open **Settings → Account → Personal info** to view the signed-in account’s email and phone number. This is a separate, read-only screen with a back button. Missing/empty Auth fields display **Not provided**; email signup does not collect a phone number. No new contact permissions or SMS provider are required.

The screen fetches the current user through `client.auth.user()` on entry and when pulled down to refresh, rather than relying on possibly stale cached session fields. The existing shared SDK client supplies the current session. Callers cannot provide another user’s ID, and contact fields are never added to discovery cards, public profiles, or logs. No schema migration, Edge Function deployment, or new stored copy of the contact details is needed.

## Structure

- `App/Features/Profile/PersonalInfoView.swift`: private contact rows, loading/error/retry UI.
- `Sources/NewToTownCore/Account`: contact projection, service contract, and state model.
- `Sources/NewToTownSupabase/Account`: current-user Auth adapter.
- `Tests/NewToTownCoreTests/Account`: missing fields, reload failure/retry, and cancellation coverage.

Views do not construct backend clients. The settings screen receives a service interface; its destination owns transient contact state. Reload keeps the current details visible while fetching. A failed request clears them and offers retry. Cancellation does not publish the interrupted response; it keeps previously loaded details, or offers retry if nothing has loaded yet. No account editing or phone verification is introduced.

## Phone acceptance

1. Sign in with an existing account. Open Settings and tap Personal info under Account. Confirm the email matches that account and an absent phone says Not provided.
2. Return to Settings, reopen the details screen, and confirm navigation and logo/margins remain consistent.
3. Disconnect and reopen. Confirm the error offers retry and does not show cached contacts as a successful result. Reconnect and retry.
4. Sign out and use a second account. Confirm the screen shows only the second account’s details and contact fields remain absent from discovery.

## Refresh behavior

Discovery (including Connections), Settings visibility, and Personal info use native iOS pull-to-refresh. Vertical bouncing stays enabled for short content and empty states. Each gesture awaits the existing model’s load operation; errors keep a Try again action. No custom gesture recognizer or additional data layer is introduced.

On an iPhone, pull down from the top of each screen and check that the refresh indicator ends when loading completes. Repeat on an empty discovery feed and on Personal info with the network disconnected, then reconnect and retry.

Cancelled read-only refreshes retain the last loaded Discovery feed or contact details. An interrupted initial load offers retry instead of an empty screen. Discovery mutations still discard cached people when their result is uncertain. Regression tests cover cancellation reported by throwing and by a late response, plus a successful subsequent refresh.
