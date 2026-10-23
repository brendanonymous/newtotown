# Private messaging backend

The backend supports one text conversation per mutual connection. The Messages tab lists conversations; a Message action on each mutual connection opens chat. The UI PR adds text composition, safe send retries, earlier-message paging, and blocking. This implementation follows the [approved schema](messaging-schema-proposal.md).

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
- `supabase/migrations/20261018005802_private_messaging.sql`: private tables, indexes, server-only RPCs, and the shared block/send lock.
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

**Deployed October 17, 2026 (Arizona).** Messaging version 1 and discovery/delete-account version 3 are active with gateway JWT verification. The approved messaging migration is deployed as `20261018005802`; its local filename is aligned to that hosted version, without changing its SQL. Live missing/malformed-token requests return 401, and hosted catalog checks confirm RLS and absent client table/RPC privileges. No real user received a test message. Authenticated two-account acceptance still requires owner device testing.

Do not blindly push all migrations: the historical profile migration has a documented local/hosted version mismatch; see [photo deployment notes](private-photos.md). Reconcile that history or apply only the reviewed new migration deliberately. For fresh projects, apply the reviewed migration and deploy `messaging`, `discovery`, and `delete-account` with their shared dependencies and JWT verification enabled.

No new bucket, paid service, extension, Realtime publication, or Swift dependency is needed. Live subscriptions, push notifications, attachments, message editing/deletion, read receipts, and moderation evidence retention are not implemented. Reporting/moderation and an explicit retention policy remain work before a broader rollout. Keep the existing controlled-pilot scope.

## iPhone implementation

`SignedInView` owns Profile/Discovery/Messages/Settings navigation. `ProfileHomeView` renders only the owner profile; signup no longer passes unrelated services through onboarding. The app root keys the signed-in shell by account UUID. Messaging state belongs to each screen and is reset on disappearance; generation checks discard late results after reset. Drafts and failed-send retry state are memory-only and cleared when leaving chat. An uncertain send may have committed: reopening fetches the server history before composing another message.

`NewToTownCore/Messaging` contains values, cursor precision, text validation, inbox state, and chat state behind `MessagingService`. `NewToTownSupabase/Messaging` supplies an account-bound adapter. It uses the existing shared Auth/session and a lightweight official Functions client whose transport binds the request to that account, then rechecks the account before publishing a response. This avoids the shared SDK transport replacing a captured Authorization header with a newly signed-in account's token. No second Auth/session store is created.

Chat accepts up to 2,000 Unicode code points. While a send is unconfirmed, its text is frozen and Retry send reuses the original UUID/body. Confirmed messages merge by server ID. A 401/404 clears private conversation state and disables composing; failed blocks immediately hide content and offer block retry. Cancelled refreshes preserve already loaded content. List/history pages deduplicate IDs. Pull-to-refresh, reopening, and returning from the background fetch replies; live subscriptions and push remain follow-up work.

Swift tests cover history/inbox paging, cancellation, uncertain sends and recovery, blocking failures, late results after reset, actual SDK HTTP payloads, cursor microseconds, status mapping, and account changes during requests. Debug-only offline UI fixtures exercise the real shell, connection-to-chat navigation, retry controls, sign-out, and a second account. They are compiled out of release builds and never populate Supabase. CI saves the iPhone test result bundle, including a chat screenshot.

Hosted advisors show informational [RLS without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) findings for the two private tables: this is intentional default-deny access with no client grants; server-only RPC checks enforce access. [Unused index](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) notices are expected before messaging traffic. Existing `rls_auto_enable` [anonymous](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)/[authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) execution warnings and disabled [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) are unchanged.

## Phone acceptance

1. Use two consenting real pilot accounts with visible, eligible, mutually connected profiles. Open Discovery → Connections → Message, then return and open the same thread from Messages.
2. Send text from A. On B, open/refresh the thread and confirm one message with the correct sender. Reply and refresh A. Test a multi-line message, the keyboard/send controls, and earlier-history paging when sufficient messages exist.
3. Interrupt connectivity during send. Confirm the draft stays frozen and Retry send recovers one server message; reopen/refresh to reconcile an ambiguous response before writing a new message.
4. Hide or block one participant and refresh the other. Confirm access pauses, composing stops, and private history is cleared. Rejoining after a hide restores the same thread; blocking has no client undo.
5. Sign out, then sign in as a different account on the same phone. Confirm no previous inbox, chat, draft, or retry state appears.
6. With disposable consenting test accounts, verify deletion confirmation mentions conversations, cancellation makes no change, and confirmed deletion removes the thread from the other participant after refresh.

## First-message transition

The `started_conversations` migration changes list queries only. Empty conversations stay in Connections; Messages lists only conversations with at least one committed message. The first saved message moves both participants on their next refresh. Opening a thread, an invalid send, or an uncommitted failure does not move it. A lost response after a committed send still moves it on refresh; the existing retry key prevents duplicate messages. Mutual decisions and blocking/visibility authorization remain unchanged. Apply the migration after review before distributing the updated iPhone app. No hosted deployment is included in this PR.
