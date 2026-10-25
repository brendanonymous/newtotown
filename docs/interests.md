# Profile interests and Discovery filters

Schema and any-selected-interest matching approved October 24, 2026. The backend PR adds the catalog, atomic selection saves, filtering, and public-card projection. The iPhone editor and filter controls follow separately; older app builds ignore the additive `interests` card field.

## Ownership and API

`private.interest_categories` and `private.interest_options` contain a curated catalog with stable text IDs. `private.profile_interest_selections` holds public profile choices; `private.discovery_interest_filters` holds a separate private filter set. All four tables enable RLS and have no member/anonymous table grants. Only the service role may invoke their SECURITY INVOKER RPCs. Account deletion cascades through both user selection sets.

The `interests` Edge Function requires a bearer session and resolves the live Auth identity before using the service role. Clients cannot provide an owner ID. Requests are limited to 4 KiB. All responses are uncached and project only documented fields.

- `{ "action": "load" }` returns `categories: [{ id, title, options: [{ id, title }] }]`, `profile_option_ids`, and `filter_option_ids` for the caller.
- `{ "action": "save", "selection_kind": "profile", "option_ids": ["golf", "coffee"] }` replaces profile choices.
- Use `selection_kind: "filters"` to replace Discovery filters. An empty array clears the chosen set.
- Saves return the same complete owner response. Missing profiles return 404; invalid choices return 400; unavailable operations return a sanitized 503. Save/reload the complete selection set when editing, rather than sending additions.

The database locks the owner's profile row, rejects unknown/inactive/duplicate/null options and more than three selections per category, then replaces that set atomically. Concurrent replacements serialize; the later complete save wins. A failed validation preserves existing selections. Editing interests never enables profile visibility or changes age settings. Display order comes from the catalog, not option IDs.

## Discovery and public profiles

A candidate matches if they have any active interest selected in the viewer's filters. No active filters means every otherwise eligible candidate can appear. Matching happens before the 20-card feed limit. Age, visibility, review eligibility, decisions, and reporting/block rules still apply. Connections and messaging do not require an interest match.

Authorized Discovery and conversation profiles include `interests: [{ id, category_id, title }]`. No filter selections or private profile fields are exposed. Retiring an option hides it from the catalog, current selections, public cards, and matching. A filter containing only retired options behaves as no active filter. Historical selection rows are retained until the next replacement or account deletion.

## Deployment and tests

Apply the CLI-generated `20261025043811_profile_interests.sql`, then deploy `interests`, `discovery`, and `messaging` with their shared dependencies and JWT validation enabled. Do not deploy the updated handlers before the migration. The current app's backend remains unchanged; the isolated test project is the initial target.

`supabase/tests/interests.sql` verifies limits, invalid choices, replacement rollback, separate owner/filter state, matching before pagination, age/visibility/block checks, unchanged connections/messaging, safe public projection, retirement, permissions, category foreign keys, and account deletion. `interests_concurrency.py` races real independent sessions to verify replacement serialization. Deno tests cover live Auth ownership, strict bounded requests, upstream error sanitization, catalog validation and public projection; existing server/SQL suites remain regression checks.

Hosted Auth, Storage uploads, and the future iPhone interest editor require separate end-to-end acceptance. Do not fabricate acceptance receipts for real people when seeding test data.

## Isolated hosted verification — October 24, 2026

The new schema and five functions are deployed only to `newtotown-test` (`acmrnolvakubxnaxwpzt`). A rollback-only hosted check created a temporary profile, saved profile interests and separate filters through the service-role RPCs, and discarded the fixture. No synthetic accounts or photos have been retained yet. The hosted migration history was aligned with repository filenames after provisioning, including correcting a tool-generated timestamp collision; the original app project's historical mapping was not changed.

Security advisors report only informational “RLS enabled, no policy” findings on service-only private tables. This is intentional: client grants are revoked, RLS denies members by default, and authenticated handlers use narrowly scoped RPCs. Do not add permissive member policies to silence these findings.

Performance review added `20261025044701_interest_selection_indexes.sql` to cover both columns of each selection foreign key while retaining option-first matching lookups. Apply this follow-up migration after the interests schema. Unused-index notices are expected in an empty testing project; keep the matching/history indexes until real query usage can be assessed.
