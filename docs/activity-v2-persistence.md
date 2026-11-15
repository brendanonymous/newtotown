# Activity v2 persistence

Implements the approved [schema/API design](activity-discovery-v2.md) without enabling a client capability or changing the legacy endpoints. Deployment remains limited to the isolated test project after code review.

- `activity_v2_catalog_tables`: normalized catalog, owner selections, setup state, future feed-session storage and disabled rollout flags. The seed comes from `supabase/catalog/activity-v2.json`; all 557 IDs are retained, with 50 flagged IDs unpublished. SQL tests fingerprint every category, interest and membership, including labels and ordering.
- `activity_v2_owner_persistence`: service-only owner RPCs for loading/importing, Basics, photo-step completion, Looking For, public interests and private filters. Auth-row and profile-row locks serialize account edits. Every successful save advances `selection_revision`; a stale revision fails with SQLSTATE `40001`/`stale_selection` before replacing anything. The Edge adapter will translate this to HTTP 409.

The initial migration imports existing accounts once. Later accounts created by legacy clients import when they first enter v2. Only exact, active, published interest IDs copy; original rows remain in the independent legacy tables. Incomplete filter migrations require explicit review. Retiring a saved v2 filter also requires review on the next owner load. V1 writes never replace v2 selections.

New-account setup requires the existing agreement receipt. Only first-time v2 profile creation initializes age defaults; editing a birthday preserves the saved range. Photo completion checks actual Storage metadata and excludes the review selfie. Completing optional Interests validates the earlier steps. Removing the last saved photo retains completion history and exposes `has_photo: false` for Discovery eligibility.

All added tables use private-schema RLS and deny client access. RPCs use SECURITY INVOKER, an empty search path and service-only grants. Trusted callers must resolve the live authenticated account before invoking an owner-selecting RPC. Looking For count/order constraints also protect direct privileged writes, including concurrent inserts. Feed tables are reserved here; ranking and pagination are implemented separately.

## Checks

Apply `supabase/tests/auth_fixture.sql` and all migrations to a disposable PostgreSQL 17 database, then run `supabase/tests/activity_v2.sql` along with the existing SQL suites. With the local database environment configured, run:

```sh
NEWTOTOWN_TEST_DATABASE=1 python3 supabase/tests/activity_v2_concurrency.py
```

The concurrency runner refuses a real Supabase Auth schema. CI runs it alongside the messaging and legacy-interest races. The SQL suite verifies full-catalog saves, migration isolation/review, setup interruption/completion, priorities, rejected writes, privileges and account/feed deletion cascades.

This PR does not deploy Edge Functions, expose a public catalog, implement screens, rank profiles or distribute an app. Both new feature flags remain false.
