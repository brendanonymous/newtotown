# Profile interests and Discovery filters

Schema and any-selected-interest matching approved October 24, 2026. The backend PR adds the catalog, atomic selection saves, filtering, and public-card projection. The iPhone editor and Discovery filters use the same catalog; older app builds ignore the additive `interests` card field.

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

## iPhone controls

Profile → Edit interests edits public profile choices. Profile → Preferences → Interests edits private Discovery filters. Both show the five catalog categories and allow zero to three choices per category. At three selections, other choices in that category are disabled; selected choices can still be removed. Save replaces only the edited set, and clearing all choices is supported. Saving filters refreshes Discovery without changing existing connections or conversations.

Core owns catalog validation and selection state; the Supabase adapter owns authenticated transport. The SwiftUI editor renders the catalog without duplicating its options. Shared profile cards show the public interest tags in Profile, Discovery, and conversation profiles. Responses after an account reset are discarded.

Validation: 106 Swift package tests pass, including selection limits, clearing, failed-save retry, account isolation, wire requests, and legacy card decoding. The simulator journey verifies profile persistence, separate filters, the three-choice limit, and clearing filters. Fifty internal demo accounts are now seeded in the isolated project; hosted authenticated catalog/filter/photo acceptance also passed.

## Catalog updates and future experiments

The catalog is server data, not a Swift list. Add or reorder options with a new versioned migration; never edit an already deployed migration. Keep stable option IDs when changing display labels. The expanded catalog migration adds Gun Range, Combat Sports, TSL's, Dive Bars, DIY, Mogging, and Poker in the owner's proposed order. It keeps existing IDs, selections, retirement flags, categories, and the three-per-category selection limit. All seven additions start active, for 37 available options across five categories. The offline iPhone fixture mirrors these choices but never supplies the live catalog.

`active = false` retains an option and its selection rows in the backend while excluding it from the editor, public profile tags, and Discovery matching. It also prevents new saves of that option. Reactivation restores retained selections unless the member has since replaced their complete choice set. This is a global retirement/staging switch, not an A/B assignment system.

For future A/B tests, keep catalog IDs and saved choices stable, and add separate server-controlled exposure rules, persistent cohort assignment, and event tracking. Hiding an experimental choice from a new-selection picker should not erase existing profile tags or silently change matching. No experiment tables, cohorts, analytics SDK, or random client-side catalog slicing are introduced in this migration.

For this rollout, apply `20261025204822_expand_interest_catalog.sql` to the isolated test project. The app fetches the updated list when the interests editor is reopened; no app rebuild or Edge Function redeployment is needed. `supabase/tests/interest_catalog.sql` verifies new choices through the existing RPCs, category limits, matching, inactive-option exclusion, and preservation/reactivation of saved choices.


The October 25 deployment to `newtotown-test` applied this migration through the CLI with the repository timestamp recorded in migration history. Authenticated hosted acceptance returned all 37 active options, including the seven new labels, across five categories; Discovery and a signed private photo download also passed. Counts and digests of the existing 150 profile-interest rows and 60 filter rows were unchanged. All ten SQL suites passed after replaying all thirteen migrations into a fresh local database. The original app project was not modified.


The next social-catalog migration adds `chess` first and `sports_betting` last, and retires `board_games` without changing its ID or stored selections. The resulting catalog has 39 stored options and 38 active choices. New seed inputs use Chess; existing seeded accounts are not rewritten. See [the catalog migration guide](catalog-migrations.md) for copyable CLI steps, ordering rules, test/deployment checks, and the distinction between migration timestamp order and UI display order.


Hosted verification of `20261025210222_chess_and_sports_betting.sql` returned 38 selectable options across five categories, with Chess first and Sports betting last in Social & hobbies. Board games remains inactive at position 10. Existing selection counts and digests were unchanged. All fourteen migrations replayed successfully, all ten SQL suites and six seed tests passed, and all fifty future seed profiles validated against the active catalog. Authenticated Discovery/catalog/private-photo checks also passed; only the isolated test project was updated.
