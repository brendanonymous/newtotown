# Private messaging backend

The backend supports one text conversation per mutual connection. The iPhone conversation UI is a separate PR; the current app still displays its existing Connections screen. This implementation follows the [approved schema](messaging-schema-proposal.md).

## Access and data

`private.conversations` stores the canonical participant pair, creation time, and last activity. `private.messages` stores immutable text, sender, database timestamp, and a client retry UUID. The unique participant pair prevents duplicate threads. The unique conversation/sender/retry key returns the original message on an identical retry and returns a conflict if the text changes. Retries do not change inbox activity.

Every operation requires both reciprocal connect decisions and current discovery eligibility. Hiding a profile, losing photo/review eligibility, suspension/rejection, or a block pauses access for both participants. Messages remain stored while access is paused. A block has no client undo in the current pilot. Deleting either account cascades through the conversation and deletes the entire thread, including both people's messages; the other profile remains. Provider backup retention is separate.

The endpoint resolves the caller through Auth. Request bodies cannot select a caller/sender. Server-only `SECURITY INVOKER` RPCs validate membership and current eligibility; the tables have RLS enabled and no client privileges or policies. The server role bypasses RLS, so the RPC checks are mandatory. No new service credential belongs in the app.

Open/send and block share a transaction-scoped lock for the canonical pair. A send waiting behind a block rechecks eligibility after acquiring the lock and fails once the block commits. A send that acquired the lock earlier can commit before the block. Already downloaded content cannot be recalled.

## HTTP contract

POST to `/functions/v1/messaging` with a Bearer session and one of these exact bodies:

```json
{"action":"list"}
{"action":"open","target_id":"<peer UUID>"}
{"action":"history","conversation_id":"<conversation UUID>"}
{"action":"send","conversation_id":"<conversation UUID>","client_message_id":"<stable retry UUID>","body":"Coffee on Saturday?"}
```

List/history accept an optional `cursor` object containing `time` (ISO timestamp including timezone) and `id` (UUID). Copy the returned cursor without truncating its timestamp precision. The database validates cursor ownership; history cursors must identify a message in that conversation. Unknown fields, caller IDs, paths, supplied timestamps, empty/whitespace-only text, and bodies over 2,000 Unicode code points are rejected. Request bodies are bounded to 32 KiB while streaming. Whitespace inside a valid message is preserved. Generate one retry UUID per authored message and reuse it after a timeout or ambiguous failure.

Responses:

- **List:** `{ "conversations": [...], "next_cursor": {...} | null }`, at most 50 threads, newest activity first.
- **Open:** the existing or newly created conversation.
- **History:** `{ "conversation": {...}, "messages": [...], "next_cursor": {...} | null }`, at most 50 messages, newest first. The UI can reverse a page for display.
- **Send:** the saved message, including its server ID and timestamp. The same response is returned on an identical retry.

Conversation projections include only ID/timestamps, the other participant's public card with a 60-second profile-photo URL, and the last message or null. Messages include only ID, conversation ID, sender ID, retry ID, body, and timestamp. Private profile fields/selfies are never projected or signed. Sends do not sign photos. Responses are `Cache-Control: no-store`; logs contain no message bodies or credentials.

HTTP errors are 400 for invalid input/cursors, 401 for absent/invalid identity, 404 for unavailable threads, 409 for changed-text retry conflicts, 405 for unsupported methods, and 503 for upstream/transport failures. Nonexistent and unauthorized conversations use the same unavailable response. A failed or timed-out send may already have committed: retain its retry UUID and retry the same body. Photo signing can fail after an open has committed; repeat open safely.

An active inbox can move between pages when new messages arrive. The UI must deduplicate conversation IDs and reload the first page to reconcile activity. Message paging uses timestamp/UUID tie-breakers and validates the full cursor.

## Structure

- `supabase/functions/messaging`: server bootstrap, command parsing, response projections, handler, and tests.
- `supabase/functions/_shared`: verified Auth lookup, bounded HTTP input, and public profile-photo projection/signing shared with existing endpoints.
- `supabase/migrations/20261018002833_private_messaging.sql`: private tables, indexes, server-only RPCs, and the shared block/send lock.
- `supabase/tests/messaging.sql`: permission, retry, lifecycle, validation, pagination, and catalog-security checks.
- `supabase/tests/messaging_concurrency.py`: real concurrent transaction tests using Python's standard library and `psql`.

## Validation

CI runs all migrations and SQL suites against an isolated PostgreSQL 17 database seeded by `auth_fixture.sql`, then runs the concurrency harness. The harness refuses to run unless `NEWTOTOWN_TEST_DATABASE=1` and the database has the minimal one-column Auth fixture; never run it against a hosted project. It commits reserved test fixtures only inside that disposable database and removes them in `finally`.

```sh
# Server checks require no project credentials.
npx --yes deno@2.9.6 fmt --check supabase/functions
npx --yes deno@2.9.6 check supabase/functions/messaging/index.ts supabase/functions/discovery/index.ts supabase/functions/delete-account/index.ts
npx --yes deno@2.9.6 test supabase/functions

# Against an isolated database with all migrations and auth_fixture.sql applied:
psql -v ON_ERROR_STOP=1 -f supabase/tests/messaging.sql
NEWTOTOWN_TEST_DATABASE=1 python3 supabase/tests/messaging_concurrency.py
```

Use ordinary `PGHOST`, `PGPORT`, `PGUSER`, and `PGDATABASE` settings for the isolated database. Existing discovery/deletion handler tests run after the shared-helper extraction. SQL checks verify RLS, absent client grants/function execution, safe function search paths, and column-limited server updates. Local Supabase CLI advisors also pass on the disposable database; hosted advisors are still a deployment check, not a result claimed by this PR.

## Deployment and scope

**Not deployed.** Do not blindly push all migrations: the historical profile migration has a documented local/hosted version mismatch; see [photo deployment notes](private-photos.md). Reconcile that history or apply only the reviewed new migration deliberately. Then deploy `messaging` with its shared dependencies and JWT verification enabled. Deploy the refactored discovery/deletion bundles with their shared Auth dependency as well; the currently hosted bundles remain unchanged until then. Run hosted advisors and authenticated acceptance checks before enabling the UI.

No new bucket, paid service, extension, Realtime publication, or Swift dependency is needed. Live subscriptions, push notifications, attachments, message editing/deletion, read receipts, and moderation evidence retention are not implemented. Reporting/moderation and an explicit retention policy remain work before a broader rollout. Keep the existing controlled-pilot scope.
