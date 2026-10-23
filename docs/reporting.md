# Connection reports

Approved October 22: Connections offers **Report** instead of Block. Choose a behavior-based reason, optionally add up to 1,000 Unicode code points, then submit. A receipt confirms storage; reporting does not block, unmatch, or message anyone. Blocking remains available inside Chat.

## Boundaries

- `App/Features/Moderation`: the report sheet.
- `Sources/NewToTownCore/Moderation`: reason/payload/service and submission state. An uncertain response freezes the payload and retry ID until retry or dismissal.
- `Sources/NewToTownSupabase/Moderation`: account-bound adapter using the shared SDK session.
- `supabase/functions/reports`: verifies live Auth, strictly validates the command, and calls a service-role-only RPC.
- `private.profile_reports`: reporter, reported profile, reason, optional details, retry ID, timestamp, and review status. RLS is enabled with no client policies or table grants. The receipt contains only an ID.

Only recorded mutual connections are reportable. Hiding or blocking after connecting does not prevent a report. Neither profile's birthday, contact info, photo, selfie, or message history is copied into the report. Deleting either account cascades its reports; this matches the pilot's account-deletion policy. Retention beyond account deletion would need a separate reviewed policy.

## Manual review

Reports do not trigger notifications or automatic enforcement. Review in Supabase SQL Editor using a trusted project account:

```sql
select id, reporter_id, reported_id, reason, details, created_at, status
from private.profile_reports
where status = 'pending'
order by created_at, id;
```

After reviewing a particular ID, update its status to `reviewed` or `dismissed`. There is no client moderation API, and changing status does not itself restrict a member.

## Rollout and verification

After code review, apply the `profile_reports` migration, deploy the `reports` function with JWT verification enabled, then distribute the client. Do not blindly push historical migrations; see backend setup. This PR does not deploy or send reports to the shared pilot.

SQL tests exercise service-only access, eligibility, retries/conflicts, details bounds, no automatic blocking, reports after blocking, and deletion cleanup. Handler tests check authenticated identity, strict commands/body limits, safe responses, and status mapping. Swift tests cover stable retries, late-response cleanup and adapter contracts. Simulator journey: Connections → Report → choose reason → Submit → Done; the connection remains available.
