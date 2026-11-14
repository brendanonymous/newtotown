# Activity Discovery v2: schema and API proposal

Status: **awaiting schema approval**. This PR contains design, canonical data and executable contract checks only. It creates no database objects or deployed endpoints. Implement migrations only after this proposal is approved.

## Approved behavior

Scottsdale-only; existing 18+ eligibility and private birthdays; required name/job/bio; one to three photos; 1–5 Looking For choices; zero to two ordered priorities; optional interests with no product selection cap. Setup follows Basics → Photos → Looking For → Interests after existing authentication/agreement acceptance. Saved steps resume across devices. Existing accounts add Looking For before redesigned Discovery, while retaining their other tabs.

Use the supplied 12 categories, 557 interests and 595 memberships. The 50 `age_restricted` interests start unpublished, leaving 507 available. They are absent from v2 selection, public projection, filtering, scoring and explanations. No paid verification, proximity, numeric scores, analytics, synonyms or new audience themes are included.

Discovery honors reciprocal saved age ranges, private interest filters and existing safety/decision exclusions. New accounts initialize their age range once to age ±12 with a floor of 18; existing settings, including implicit 18/no maximum, remain unchanged. Strict results require shared Looking For. Explicit session-only expanded mode relaxes only that requirement.

## Data model for approval

Existing Auth, profiles, agreements, photos, visibility, decisions, reports and conversations remain authoritative. Do not replace the existing photo slots with a new photo table. All new tables below live in `private`, enable RLS, and revoke all access from `public`, `anon` and `authenticated`. Only narrowly scoped service-role RPCs access them after the Edge Function resolves the live Auth caller. No caller-selected owner IDs reach those RPCs from a client body. RPCs use SECURITY INVOKER with an empty search_path, explicit service-role-only EXECUTE grants, and fully qualified table/function names.

| Table | Columns and constraints |
| --- | --- |
| `looking_for_categories` | `id text` PK, `title text`, `description text`, `sort_order integer UNIQUE`. Exact 12 handoff IDs; labels/order come from the source JSON. |
| `activity_interests` | `id text` PK, `title text`, `age_restricted boolean`, `published boolean`, `sort_order integer UNIQUE`. Seed all 557; initially publish only unflagged tags. IDs remain stable when labels or publication change. |
| `interest_looking_for_links` | `interest_id` FK, `category_id` FK, `group_title text`, `group_order integer`, `sort_order integer`. PK `(interest_id, category_id)` and unique category position. Store the 595 source placements without duplicating tags. |
| `profile_looking_for` | `user_id` FK profiles ON DELETE CASCADE, `category_id` FK categories, nullable `priority_rank smallint` restricted to 1 or 2. PK `(user_id, category_id)`; unique `(user_id, priority_rank)` permits multiple unranked choices. At most five rows per owner; priorities are contiguous and inherently belong to selected categories. |
| `profile_activity_interests` | `user_id` FK profiles ON DELETE CASCADE, `interest_id` FK interests. Composite PK; no per-category or arbitrary selection count limit. |
| `discovery_activity_filters` | Same key/FK shape as profile interests, but a distinct private selection set. Empty means no interest filter; nonempty means any selected ID may match. |
| `profile_setup_progress` | `user_id` PK/FK auth.users ON DELETE CASCADE, `version integer CHECK = 2`, `entry_kind text` (`new`/`existing`), four completion booleans, nullable `completed_at`, nullable `legacy_imported_at`, `filters_need_review boolean`, `selection_revision bigint`, `updated_at`. Auth FK permits progress before Basics creates a profile. |
| `activity_feed_sessions` | `id uuid` PK, `user_id` FK profiles ON DELETE CASCADE, `mode text` (`strict`/`expanded`), `context_revision text`, `created_at`, `expires_at`. One current session per `(user_id, mode)`; 15-minute lifetime. No score or private preference data is returned. |
| `activity_feed_entries` | `session_id` FK sessions ON DELETE CASCADE, `position integer`, `profile_id` FK profiles ON DELETE CASCADE. PK `(session_id, position)`, unique `(session_id, profile_id)`. Retain ordered IDs only; derive safe public fields and shared selections when reading a page. |

V2 identifiers match `^[a-z0-9][a-z0-9_]{0,63}$`; titles retain their Unicode display spelling. The supplied IDs `3d_printing` and `3d_modeling` require a leading digit, which v1 rejects. Keep the v1 validator unchanged and implement a separate v2 validator. Add indexes for category membership, interest-to-profile lookup, filter owner/interest lookup, feed owner/expiry and each referencing foreign key. Existing profile ownership and access policies are not loosened.

RPC writes lock the owner's existing profile row before replacing selection sets. A deferred constraint trigger enforces the Looking For count/rank invariants even if privileged maintenance code writes directly. Validate all IDs and publication before any replacement; failed or concurrent saves must not leave partial selections. Deselecting rank 1 promotes the remaining rank 2 to rank 1. A Looking For save must contain at least one choice; an unsaved editing draft may be empty.

Add default-false, service-controlled flags `activity_profiles_v2_enabled` and `activity_ranking_v2_enabled` to the existing pilot configuration. Existing config responses are unchanged; v2 capabilities explicitly expose only these capabilities. Keep current photo-review behavior unchanged.

## Legacy migration and account lifecycle

The [complete ID mapping](activity-v2-legacy-mapping.md) covers all 64 legacy catalog records: 28 copyable, 33 missing canonical IDs, one retired Board Games row and two hidden tags. Copy only selections whose legacy row is active, ID exactly matches and v2 tag is published. Never infer Looking For or priorities from legacy interests. Keep original catalog/selection/filter tables intact as private v1/history data.

Import each account once in a transaction. Set `filters_need_review` if any nonempty legacy private filter cannot migrate completely. A member must explicitly save a reviewed v2 filter before entering v2 Discovery; an empty reviewed filter is allowed. Offer an owner-only notice about unavailable public interests, but do not require replacements.

After import, v2 selections are authoritative for v2 and remain independent of legacy writes. V1 APIs retain their old catalog, limits and tables. Old app edits cannot truncate v2 sets; do not introduce ongoing dual writes or guessed merges. V1 and v2 catalog edits are not synchronized after import; general profile fields, photos and saved age ranges remain shared.

Create existing-account progress from current profile/photo facts, without claiming new agreement acceptance or Looking For completion. Accounts created by an older app after deployment use the same one-time import when they first enter v2. New v2 accounts create progress after agreement acceptance and before Basics. Basics saves atomically initialize age preferences only if this is a new v2 profile and no earlier settings exist. Subsequent saves and birthdays do not reset the member's range.

Mark each setup step only after its save succeeds. Completing Interests, including an explicit empty selection, completes new-account setup only when current profile fields, saved photo and Looking For satisfy the rules. Back navigation retains saved progress; revisiting a step does not clear unrelated selections. Removing the last photo after completion leaves setup complete but makes Discovery ineligible under the existing photo rule.

Deleting an account cascades progress, selections and viewer feed sessions; deleting a peer cascades its feed entries. Existing deletion still removes Auth/profile/photo/message data. Do not change connection/chat availability based on new age ranges, Looking For or filters.

## Versioned API contracts

Use the existing shared Supabase client, account-bound Functions transport, gateway JWT validation, live Auth lookup and sanitized errors. Version names below are fixed for implementation. Request keys use snake_case; Swift adapters own CodingKeys. The versioned owner APIs use a 64 KiB request-body limit and reject duplicate/unknown/unpublished IDs rather than silently discarding them. This accommodates every current available interest without the v1 15-choice limit.

### `activity-profile-v2`

Authenticated POST commands:

| Command | Input | Result |
| --- | --- | --- |
| `load` | `action` only | Capabilities, catalog revision, private owner setup/profile state, Looking For/priorities, selected interest/filter IDs and migration-review notices. |
| `save_basics` | Validated name, job, bio, private birthday; Scottsdale fixed server-side | Updated owner state; atomic Basics completion and one-time new-account age defaults. |
| `complete_photos` | `action` only | Server checks actual owner Storage metadata, marks Photos complete and returns owner state. No client-supplied paths or approval flags. |
| `save_looking_for` | `category_ids`, ordered `priority_ids` | Atomic 1–5 selections and zero to two unique priorities; updated owner state. |
| `save_interests` | Unique `interest_ids`, `complete_setup boolean` | Atomic profile selection save. Completion validates the earlier setup requirements; empty is valid. |
| `save_filters` | Unique `interest_ids` | Atomic private filter save, clears `filters_need_review`, increments selection revision. |
| `peer` | Exactly one of `conversation_id` or `target_id` | Fresh v2 public activity metadata, only after the existing conversation/connection authorization succeeds. New Discovery filters must not revoke that existing relationship. |

`target_id` is the peer's existing profile UUID for an established mutual connection; no new connection table is introduced. Neither context permits arbitrary profile browsing. Existing report/hide/suspension rules still apply.

### `activity-catalog-v2`

Authenticated POST `{ "action": "load" }` returns `revision`, the 12 categories and the 507 published interests with category/group memberships and stable ordering. Hidden interest labels/IDs and review metadata never reach the client. Cache by revision within the account session; clear account-owned state on sign-out. The complete available catalog is small enough for local case/diacritic-insensitive label search. No network request per keystroke or second hand-maintained Swift catalog.

### `discovery-v2`

- `feed`: `mode` (`strict` default or `expanded`) and optional `cursor: {session_id, after_position}`; returns candidate readiness, up to 20 safe candidates and `next_cursor`. Readiness distinguishes missing photo, missing Looking For, filter review, hidden/restricted state and disabled capability.
- `decide`: `session_id`, `target_id`, `choice` (`connect`/`pass`); checks session membership and current authorization before calling the existing idempotent decision transaction. Returns a saved receipt. Advance the card only after acknowledgement; failed actions retain/reconcile the expected person.
- Keep existing visibility/report operations and immutable decisions. Connections and Messages continue to use their existing relationship authorization, with authorized v2 activity metadata supplied through `peer`.

A candidate includes existing public name/age/job/bio/city/photo fields plus `looking_for`, `interests`, `shared_looking_for_ids`, `shared_interest_ids`, `relevant_shared_interest_ids`, and nullable `explanation`. Interest objects carry canonical `id`, `title`, and `category_ids`; priorities belong to Looking For objects. Do not reuse or change the v1 category_id/15-interest projection.

Owner preview receives the same published selection labels but no shared-match treatment. Public responses exclude score/breakdown, private birthdays/contacts/preferences, unpublished tags, coordinates and moderation state. Profile photo URLs remain short-lived; only returned authorized profile slots are signed.

Use existing HTTP semantics (401 signed out, 400 invalid input, 404 unavailable peer, 503 sanitized upstream failure). Add 409 `stale_selection`/`feed_expired` with no sensitive payload; the client offers to reload newer owner state without silently discarding an editor draft, or refreshes an expired feed instead of guessing defaults. Save commands carry the owner state's selection revision to prevent a stale editor from silently overwriting newer changes. Successful writes increment it.

## Ranking, pagination and explanations

Adapt the supplied pure formulas into the existing Deno server, without adding a Node service. Inputs are request-time adult age and published canonical selection IDs. Remove the draft location requirement, distance defaults, group-configurability and arbitrary upper-age cap; this rollout has no location or audience-setting UI. Validate weights, IDs and typed runtime inputs before scoring.

Use the exact age/intent/interests formulas, with weights 35:25:10 normalized by their sum. Sort score descending, age difference ascending, profile UUID ascending. Photos never reach the scoring function. Compute all shared interest IDs, including those outside mutually selected umbrellas. Relevant shared IDs only choose the factual explanation; they do not suppress other highlights.

The database shortlists at most 500 otherwise eligible Scottsdale candidates after reciprocal ranges, visibility/moderation, prior decisions, private filter and mode-specific intent checks. Order shortlist selection by age difference then UUID; score that shortlist before taking the first 20. This is a bounded shortlist, not a claim of globally optimal ranking beyond 500 candidates. Benchmark larger fixtures before expanding beyond the controlled pilot.

Store the ranked ID order in the private feed session. Its context revision covers the viewer's selections/ranges, current UTC age date, catalog and scorer versions. Reject an outdated/expired context and refresh. Recheck each candidate's current safety, range/filter and mode eligibility before projection/signing; skip unavailable entries. Cursor ownership is checked server-side, even if the caller edits the cursor. Return the last scanned position, so skipped entries cannot create pagination loops. Refresh starts a new session. Repeated decisions remain safe through the existing unique decision keys.

Return expanded-mode results only on an explicit request after strict exhaustion. The UI labels the mode and offers a return to strict. Expansion persists only for that signed-in app session; signing out or restarting resets strict. It does not widen age ranges, ignore private filters or include profiles without Looking For.

Use deterministic text templates from returned category/interest labels, e.g. a common category plus a relevant common interest, or category-only when interests do not overlap. Return no explanation when there is no actual overlap; expanded cards must not fabricate compatibility. No LLM or numeric score in API/UI.

## iPhone integration and verification

Keep feature-based App/Core/Supabase boundaries. Add a focused profile-setup coordinator instead of adding photos/ranking to the account lifecycle model. Extend existing pushed editors/Back behavior. Show all Looking For and six interests initially; shared interests come first. Show all expands the remainder, with every displayed shared tag using color plus an icon/accessibility cue. Preserve galleries, crop ratio, pending-photo exit protection, decision spacing and account-scoped image preloads.

Release new capabilities off by default. Deploy additive schema/functions only to newtotown-test after schema/code review. V1 endpoints remain available. Enable profiles and then ranking only after their tests pass. A disabled v2 ranker presents a controlled unavailable state; never fall back to weaker legacy eligibility for v2 accounts. TestFlight archives must come from reviewed, merged source, excluding unrelated local edits. No production deployment in this scope.

Required acceptance: exact catalog/hidden counts; duplicate and invalid-ID rejection; rank/count invariants and concurrent saves; full available-catalog saves over 4 KiB; migration/review gating; old-client isolation; new/restored/interrupted setup; reciprocal boundaries and birthdays; strict/expanded ranking and ties; arbitrary cursors; changed/deleted/blocked candidates; profile/connection/chat visibility; deletion cascades; Dynamic Type/light/dark/Reduce Motion; photo/signing/transition regression; two separate device accounts on the QA build.

## Proposed PR tracker

1. Callback baseline repair (#56; older-runtime CI verification pending).
2. This schema/API/canonical-data design (approval gate; no DDL).
3. Catalog, selection/progress persistence, migration and SQL tests.
4. Versioned services, Core contracts, catalog and compatibility.
5. Looking For editor.
6. Searchable public-interest/private-filter editors.
7. Resumable setup and existing-account Discovery gates.
8. Ranked feed, snapshot pagination and rollout flags.
9. Shared profile presentation and explanations.
10. Synthetic fixtures, hosted test acceptance and QA TestFlight rollout.
