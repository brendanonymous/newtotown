# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared.

`NewToTownCore` contains profile rules, the onboarding model, and its service interface. It has no SwiftUI or Supabase dependency. `NewToTownSupabase` depends on the core and the official SDK; it contains the concrete service and public connection configuration. Configuration tests reject malformed endpoints and privileged-key formats, but server authorization still relies on RLS.

`NewToTownApp` reads configuration and owns the onboarding model. Views receive that model instead of creating backend clients. The welcome preview passes no model and makes no backend connection. The dependency direction is `App → NewToTownSupabase → NewToTownCore`, with views also importing the core directly.

Supabase calls live in `SupabaseOnboardingService`, behind `OnboardingService`. `OnboardingModel` owns transitions, loading, and retryable errors; SwiftUI views render it. Views do not construct database queries. Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The app embeds public connection values through build configuration. It uses the pinned official Supabase Swift SDK for email OTP, Keychain session persistence, refresh, and profile queries. The SQL migration and policy tests are versioned under `supabase/`. Hosted schema changes are not applied automatically.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Verification selfies will require private storage and a separate reviewer authorization boundary. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.

## Maintaining the structure

Keep each feature's SwiftUI screens under `App/Features/<Feature>`, behavior and service interfaces under `Sources/NewToTownCore/<Feature>`, and its concrete backend service under `Sources/NewToTownSupabase/<Feature>` when that feature is added. The current integration has only two files; it does not need extra folders yet. Match behavioral test folders to the features they exercise.

- Views own transient input and presentation; models own workflow decisions, loading, errors, and service calls. Keep main-thread UI state explicit with `@MainActor`.
- Core types and interfaces must not import SwiftUI or Supabase. Backend services return app models rather than SDK response types.
- Construct dependencies at the app boundary. When a second backend service is introduced, share one configured Supabase client/session across services rather than creating independent clients in each feature.
- Keep profile data private. Discovery needs its own limited projection and read model; never reuse the private profile payload containing birthday as a public card.
- Extract a view or service when it gains a distinct responsibility or is reused. Avoid generic base models, repository frameworks, and one-file-per-property refactors.
- Test validation, transitions, recovery, and permission boundaries. A simulator smoke test does not replace physical-device acceptance of camera, email, and session behavior.

## Structure review — October 7, 2026

Reviewed the package dependency graph, app dependency construction, onboarding model and screens, Supabase service, existing tests, and CI. The current feature follows the boundaries above: no SDK imports or queries in views/core, one app-owned onboarding model, a service fake for workflow tests, and database authorization tests independent of the UI. No production-code refactor is required before the next feature.

Keep photo submission and review separate from the existing onboarding model. When authenticated features expand, introduce app-level session/navigation state at the composition boundary so onboarding does not become the owner of discovery, chat, or moderation.
