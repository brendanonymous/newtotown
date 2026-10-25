# Profile interests and Discovery filters

Status: product direction confirmed October 24, 2026; schema and matching rule awaiting review. No database, endpoint, or interests UI changes have been implemented. This follows the request to review schema designs before implementation.

## Product behavior

Users choose zero to three interests in each of five categories. All categories are optional. Interests describe the user and appear on their authorized public profile. Separate choices in the existing Preferences screen filter Discovery; choosing a personal interest does not automatically enable a filter. Age preferences continue to apply. Existing connections and messages remain available.

| Category | Proposed initial options |
| --- | --- |
| Sports & fitness | Golf, Pickleball, Gym, Running, Basketball, Tennis |
| Outdoors | Hiking, Camping, Cycling, Fishing, Kayaking, Dog walks |
| Food & drinks | Coffee, Craft beer, Dining out, Cooking, Barbecue, Wine |
| Arts & entertainment | Live music, Movies, Comedy, Museums, Photography, Theater |
| Social & hobbies | Board games, Video games, Volunteering, Professional networking, Reading, Cars |

The five categories and inclusion of Professional networking are confirmed. The initial option list above is the proposed first catalog. No alcohol interest is required.

## Schema proposed for approval

Use curated, stable text identifiers rather than free-form labels or unvalidated JSON. Keep raw tables in the private schema with RLS and no direct client privileges. An authenticated endpoint returns the catalog and the owner's selections, and service-only SECURITY INVOKER RPCs perform writes.

| Table | Fields and constraints |
| --- | --- |
| `interest_categories` | `id` primary key, `title`, `sort_order` |
| `interest_options` | `id` primary key, category foreign key, `title`, `sort_order`, `active`; unique category/option pair |
| `profile_interest_selections` | Profile user foreign key with delete cascade, category ID, option ID; unique user/option; composite foreign key ensures the option belongs to its category |
| `discovery_interest_filters` | Separate owner-scoped selection set with the same keys and constraints; never projected onto another user's card |

The endpoint resolves the live Auth user; clients cannot submit an owner ID. Saving either selection set is one transaction: lock that owner's profile row, validate active catalog IDs and uniqueness, enforce at most three selections per category, then replace the prior set. Empty sets clear saved choices. Concurrent saves serialize so the limit holds; the later complete save wins. Revoke direct client writes and public RPC execution. Do not use editable Auth metadata for these settings.

Public interests are returned only through the existing eligibility-checked Discovery/conversation card projections. Raw selections and private filters are not exposed through unrestricted profile reads. Account deletion cascades through both selection sets. Existing users start with no interests or filters; they are not forced through onboarding again.

## Matching choice awaiting approval

Recommended: a candidate matches when they have **any** selected interest across all filtered categories. With no filters selected, every otherwise eligible candidate can appear. A candidate with no interests does not match an active interest filter. Existing age, location, visibility, reporting/blocking, and eligibility rules still apply.

Alternative: require at least one matching option in **each** category containing a filter, while allowing any selected option within a category. This is more precise but can make a small pilot's feed much narrower. Do not silently select a matching rule before review.

## Implementation PRs after schema approval

1. Catalog, selections/filter RPCs, authenticated endpoint, and Discovery filtering. Verify owner scoping, unknown/inactive IDs, duplicates, empty saves, concurrent limits, account deletion, and unchanged messaging eligibility.
2. Swift domain models, account-bound adapters, and the optional chip editor/public interests. Each category shows its count; selecting three disables the other options while leaving selected options removable. Profile interests live in profile editing; filters live beside age preferences. Test save/reload, clearing choices, max-three behavior, and access across accounts.

Keep the feature in `NewToTownCore/Interests`, `NewToTownSupabase/Interests`, and `App/Features/Interests`. Reuse account-bound service construction and the existing profile-card layout. Keep the age model focused on age. Final migrations must be generated with the Supabase CLI and verified locally before any hosted rollout.
