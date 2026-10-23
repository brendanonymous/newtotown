# Connection reports

Approved October 22: Connections offers **Report** instead of Block. Choose a behavior-based reason, optionally add up to 1,000 Unicode code points, then submit. The confirmed report also removes the connection from Discovery, Connections, and Messages for both participants and prevents further contact. The same Report sheet opens from Chat. This behavior supersedes the initial report-only design.

## Boundaries

- `App/Features/Moderation`: the report sheet.
- `Sources/NewToTownCore/Moderation`: reason/payload/service and submission state. An uncertain response freezes the payload and retry ID until retry or dismissal.
- `Sources/NewToTownSupabase/Moderation`: account-bound adapter using the shared SDK session.
- `supabase/functions/reports`: verifies live Auth, strictly validates the command, and calls a service-role-only RPC.
- `private.profile_reports`: reporter, reported profile, reason, optional details, retry ID, timestamp, and review status. RLS is enabled with no client policies or table grants. The receipt contains only an ID.

Only recorded mutual connections are reportable. Report insertion and the existing pair-block action run in one database transaction under the same pair lock as sends. Both commit or neither does. Repeating a retry ID returns the same receipt; changing its payload fails before another connection is removed. Hiding or blocking after connecting does not prevent a report. Neither profile's birthday, contact info, photo, selfie, or message history is copied into the report. Deleting either account cascades its reports; this matches the pilot's account-deletion policy. Retention beyond account deletion would need a separate reviewed policy.

## Manual review

Reports do not trigger notifications or global account suspension. The pair-specific removal is immediate; the reported member can still use the app with other people. Review in Supabase SQL Editor using a trusted project account:

```sql
select id, reporter_id, reported_id, reason, details, created_at, status
from private.profile_reports
where status = 'pending'
order by created_at, id;
```

After reviewing a particular ID, update its status to `reviewed` or `dismissed`. There is no client moderation API, and changing review status neither suspends an account nor restores a removed connection.

## Rollout and verification

Apply `profile_reports`, then the forward `report_and_disconnect` migration, deploy the `reports` function with JWT verification enabled, then distribute the client. Do not blindly push historical migrations; see backend setup. Do not test by submitting reports against real members without their authorization; the local suites use disposable fixtures.

SQL tests exercise service-only access, eligibility, retries/conflicts, details bounds, pair removal, inaccessible history and sends, reports after blocking, unchanged stored messages, rollback if blocking fails, and deletion cleanup. Handler tests check authenticated identity, strict commands/body limits, safe responses, and status mapping. Swift tests cover stable retries, late-response cleanup and adapter contracts. Simulator journeys cover reporting from Connections and Messages, cancellation preserving a draft, uncertain responses and safe retry, and removal across the signed-in lists. Seven real two-session tests cover simultaneous reports, sends, retries, and blocks.


## App cache handling

After a confirmed report sheet closes, the account-scoped signed-in shell publishes the reported profile ID. Discovery, Connections and Messages prune that person from cached data and filter late responses; unrelated people and chat drafts stay intact. The affected Chat closes and clears private content. Cancelling before submission does not mark anyone reported. Dismissing an uncertain result refreshes the originating view so a committed-but-unacknowledged report can reconcile from the server. Both app accounts receive server-enforced removal on their next request; this pilot does not provide realtime cross-device invalidation.


## Pilot deployment — October 22, 2026

Project `pnlpdevgwenkkoqjgcui` now has `profile_reports` (`20261023041649`), `report_and_disconnect` (`20261023041652`), and Reports Edge Function v1 with JWT verification enabled. Local migration filenames match the hosted ledger. The private-table/schema SQL from the original reporting PR is unchanged; the forward migration adds transactional pair separation.

A service-role probe on an existing mutual pair verified one receipt across retries, one stored report for that retry ID, and denial of discovery/messaging pair access. The entire probe was rolled back: no real report or block from verification was retained. Unauthenticated HTTP submission returns 401, and authenticated clients have neither table access nor direct RPC execution. Hosted advisors add only the expected private-table RLS-without-policies notice; the previously documented platform-helper/password notices remain unchanged.

Run this client branch on the phone to exercise the repaired report sheet. An already installed client does not receive SwiftUI fixes from a backend deployment. No TestFlight build or PR merge is performed by this rollout.
