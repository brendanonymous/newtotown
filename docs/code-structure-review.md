# Code structure review

Reviewed October 17, 2026 against `main` commit `394b3b1`, before messaging implementation. This is a source/architecture review and regression-check baseline, not a complete security or performance audit.

## Assessment

The current feature-based structure is appropriate for the app's size. Keep it. A broad directory reshuffle, generic repository layer, or shared base view model would add complexity without solving an observed problem.

| Area | Evidence | Assessment |
| --- | --- | --- |
| Dependency direction | `Package.swift`; Core imports no SwiftUI, UIKit, or Supabase | Core rules/models can be tested independently; SDK integration stays in adapters |
| Feature ownership | `App/Features`, matching Core/Supabase subfolders, mirrored core tests | Discovery, photos, account details, and onboarding have identifiable homes |
| Dependency injection | `SupabaseServices`, feature service protocols, injected Edge Function transport | One SDK client/session; screens do not construct backend clients or SQL queries |
| Shared UI | `App/DesignSystem/ProfileCard.swift`, photo style and brand components | Shared presentation is reused without moving feature behavior into design tokens |
| State and concurrency | Observable main-actor models; cancellation/retry regression tests | Existing patterns are usable; loading rules are feature-specific rather than universally interchangeable |
| Server boundaries | Small `index.ts` bootstrap files, separate handlers and photo helpers | Authentication and server-only RPCs are explicit; secret credentials stay outside the app |
| Validation | Swift behavior tests, Deno handler tests, SQL policy tests, iPhone signup smoke test | Useful coverage of rules and permission boundaries, with the gaps below |

The largest feature view is 195 lines and the largest core model is 187 lines. These counts are context, not quality gates: responsibilities and behavior matter more than an arbitrary file limit. Swift names use upper camel case for types and lower camel case for members; SQL uses snake case. Feature types and service names are descriptive. Swift formatting mixes compact one-line declarations with expanded declarations, but no formatter is enforced in CI.

## Improvements to make as messaging grows

1. **Separate signed-in composition from signup.** `AppEntryView` currently routes the saved account into `OnboardingView`, which passes feature services through `OnboardingContent` to `ProfileHomeView`. Account lifecycle callbacks also live there. This works today, but adding another service would deepen signup's knowledge of unrelated features. In the messaging UI PR, introduce a small signed-in shell at the app boundary. Keep signup responsible for signup and preserve the existing single shared SDK client. Do not add messaging state or navigation to `OnboardingModel`.
2. **Extract repeated server plumbing when adding the third endpoint.** Discovery and deletion independently implement verified Auth lookup, timeouts, and sanitized responses. A small `supabase/functions/_shared` Auth/HTTP helper is justified when messaging needs the same behavior. Preserve endpoint-specific validation and response semantics; test the helper and each handler rather than building a generic endpoint framework.
3. **Add integration coverage for the new adapter and account changes.** Existing Supabase Swift tests exercise configuration, not feature wire contracts. Add messaging response decoding/transport tests with its adapter. The only current iPhone UI test covers signup validation; add conversation navigation and account-switch cleanup checks with the messaging UI. Existing SQL and handler tests remain the primary authorization checks.
4. **Keep lifecycle handling explicit.** Discovery queues overlapping refreshes; Personal info skips a second load while busy; photos preserve unsaved selections. Those distinctions are intentional enough to keep local for now. Messaging needs a defined owner for in-flight loads/sends and must clear conversation data on account change. Share mechanics only after the required behavior is clear.
5. **Refresh documentation as behavior changes.** The delivery plan still called merged discovery work the current PR, architecture omitted the Account adapter in one service list, discovery described the removed Refresh button, and account-deletion notes predated discovery tables. These documentation issues are corrected in this design draft. The historical hosted-migration mismatch remains an operational constraint to resolve before deploying future migrations.

No production source refactor is included while the schema is awaiting review. Formatting tooling can be added in a focused follow-up if desired; it does not justify reformatting the entire repository alongside messaging.

## Planned messaging placement

The first implementation PR adds only the messaging migration/tests and `supabase/functions/messaging`, plus a small `_shared` folder if needed for repeated server plumbing. The UI PR will add:

```text
App/Features/Messaging/                    screens and iOS presentation
Sources/NewToTownCore/Messaging/           value types, service contract, state
Sources/NewToTownSupabase/Messaging/       SDK adapter using the shared client
Tests/NewToTownCoreTests/Messaging/        workflow and cancellation tests
Tests/NewToTownSupabaseTests/Messaging/    adapter contract tests
```

Create these files only with their implementations. Keep authorization in the database/server rather than duplicating it as client-only restrictions. Store transport command/response types beside the adapter unless they are domain types used by the core.

## Validation baseline

`swift test` passes all 42 tests. Deno formatting checks pass for all 8 function files. Both Deno entry-point checks and all 15 handler tests pass. No new behavior or schema exists in this draft, so there is no messaging test result yet. Existing SQL suites and full iPhone builds were green on the merged PR; they are not represented as newly executed local checks here.
