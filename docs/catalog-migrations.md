# Updating and ordering the interest catalog

The app loads selectable interests from Supabase. Swift's `InterestJourneyService` is only an offline UI-test fixture. Updating catalog rows needs no app rebuild or function deployment; reopen the editor to fetch them.

## 1. Start with the latest migration files

Use a branch containing all migrations already deployed to the target project, including pending PRs until those are merged. Never edit, rename, or delete a migration after it has been applied. Create a new migration for each change.

Commands below use the Supabase CLI. If it isn't installed, replace `supabase` with `npx supabase@2.121.0`.

```bash
supabase migration new update_interest_catalog
```

The CLI creates a timestamped SQL file in `supabase/migrations`. That timestamp controls migration execution order; it is separate from interest display order.

## 2. Inspect the current catalog

In the test project's SQL Editor, run this read-only query. Include inactive rows when planning positions:

```sql
select id, category_id, title, sort_order, active
from private.interest_options
order by category_id, sort_order;
```

| Column | Meaning |
| --- | --- |
| `id` | Stable identifier such as `sports_betting`; existing selections refer to it. |
| `category_id` | One of `sports_fitness`, `outdoors`, `food_drinks`, `arts_entertainment`, `social_hobbies`. |
| `title` | The label shown in the app. Apostrophes in SQL strings must be doubled: `'TSL''s'`. |
| `sort_order` | Integer position within that category; lower numbers appear first. Gaps are fine. |
| `active` | Whether the option is available in editors, public profile tags, and matching. |

`(category_id, sort_order)` must be unique **even for inactive rows**. To append an option, choose an unused position. To move or swap options, move affected rows into verified-unused temporary positions first, then assign their final positions—all in the same transaction. Simply updating `0 → 1` can fail if position 1 is still occupied. The previous catalog migration demonstrates a multi-row reorder.

## 3. Write the change in the new file

For example, the Chess migration retires Board games and frees its position before inserting the new choices:

```sql
begin;

update private.interest_options
set active = false, sort_order = 10
where id = 'board_games';

insert into private.interest_options(id, category_id, title, sort_order, active) values
    ('chess', 'social_hobbies', 'Chess', 0, true),
    ('sports_betting', 'social_hobbies', 'Sports betting', 9, true);

commit;
```

These positions are specific to that migration's starting catalog; inspect the current rows before reusing an example. Keep the same ID for a cosmetic rename. Create a new ID for a different concept—renaming `board_games` to Chess would mislabel existing choices. Retirement retains stored selections but hides them from tags and matching; it is not a per-user A/B exposure flag.

Update offline UI fixtures and future seed inputs when relevant. Changing a seed file does not change already seeded accounts; don't rerun imports merely to update the catalog.

## 4. Test and review

Commit the new migration, related fixtures, tests, and docs to a PR. The `profile-policies` CI job replays every migration into a clean test database and runs the SQL suites, including `interests.sql` and `interest_catalog.sql`. Run the SQL checks locally in a disposable test database, or wait for the CI job to pass before applying to the hosted test project. The `auth_fixture.sql` file is only for the disposable vanilla PostgreSQL test database; never apply it to a Supabase project.

## 5. Target the test project and inspect the deployment

One-time CLI authentication and project linking:

```bash
supabase login
supabase link --project-ref acmrnolvakubxnaxwpzt
```

Enter credentials when prompted; don't put passwords or secret keys in migration files. Then:

```bash
supabase migration list --linked
supabase db push --linked --dry-run
```

Check that the pending list contains only the migrations you intend to apply. `db push` considers the **whole migration folder**, not one selected file. If history differs, first get the missing migration files; don't use `--include-all` or repair history as a shortcut.

## 6. Apply and verify

```bash
supabase db push --linked
supabase migration list --linked
supabase db push --linked --dry-run
```

The final dry run should report up to date. Re-run the catalog query and reopen Profile → Edit interests and Preferences → Interests. Confirm labels/order, selection limits, and saving. A Git merge and a database deployment are separate operations; merging this repository does not automatically deploy migrations.

Production is a separate, deliberate rollout after review and test acceptance. Check its migration history and prerequisites before linking or pushing; the original project has not received these test catalog deployments.

Reference: [Supabase database migration workflow](https://supabase.com/docs/guides/deployment/database-migrations).
