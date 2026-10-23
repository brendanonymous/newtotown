# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared. `ProfileCard` shares photo layout and public-field icons between the owner, discovery, and connections.

`NewToTownCore` contains profile rules, onboarding/photo/discovery models, typed photo requirements, and service interfaces. It has no SwiftUI or Supabase dependency. `NewToTownSupabase` depends on the core and the official SDK; it contains the concrete service and public connection configuration. Configuration tests reject malformed endpoints and privileged-key formats, but server authorization still relies on RLS.

`NewToTownApp` reads configuration and owns the onboarding model. `AppEntryView` restores the session and routes welcome/signup/saved-account screens at the window root; the signed-in app is not presented inside a signup sheet. Views receive that model instead of creating backend clients. The welcome preview supplies only a navigation callback and makes no backend connection. The dependency direction is `App → NewToTownSupabase → NewToTownCore`, with views also importing the core directly. Feature screens own transient photo/discovery/messaging state. Private contact information has its own `Account` core model/service and Supabase adapter; [Personal info](personal-info.md) is a read-only Settings destination. Saved accounts render `SignedInView` with native Profile/Discovery/Messages/Settings navigation stacks. `ProfileHomeView` renders only the owner profile. The shell owns account-action presentation, while the onboarding/account model retains sign-out/deletion state transitions.

Supabase calls live in the account, onboarding, photo, and discovery services, behind their core interfaces. `SupabaseServices` shares one client/session between them. `OnboardingModel` owns transitions, loading, and retryable errors; SwiftUI views render it. Views do not construct database queries. `FirstSignupIntroduction` presents the one-time slides; `OnboardingModel` advances only after the account-level acceptance is persisted. See [onboarding agreement](onboarding-agreement.md). Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The signup PR embeds public connection values through build configuration. It uses the pinned official Supabase Swift SDK for email OTP, Keychain session persistence, refresh, and profile queries. The SQL migration and policy tests are versioned under `supabase/`. Hosted schema changes are not applied automatically.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Selfies use owner-only private storage. The server-owned [photo-review flag](photo-review-flag.md) controls collection and eligibility requirements; reviewer authorization remains separate work. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

Discovery uses a separate authenticated Edge Function for public profile projection and short-lived profile-photo links. It shares photo-review eligibility with the flag feature and keeps private profile rows and selfies behind their existing owner policies; see [discovery](discovery.md).

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.

## Directory map

- `App/Features/<feature>`: SwiftUI screens and platform bridges.
- `App/DesignSystem` and `App/Assets.xcassets`: shared visual components and artwork.
- `Sources/NewToTownCore/<feature>`: platform-independent rules, state models, and service contracts.
- `Sources/NewToTownSupabase/<feature>`: SDK adapters; shared configuration/client construction stays at the package root.
- `Tests/<module>/<feature>` and `UITests`: core/integration-boundary tests and iPhone UI journeys.
- `supabase/functions`, `supabase/migrations`, and `supabase/tests`: server handlers, versioned schema, and policy checks.
- `Configuration`, `scripts`, and `docs`: build settings, asset tooling, and operational documentation.

A missing session clears the account ID, draft, and agreement state before returning to login. Discovery refreshes wait for an in-flight request to finish cancellation rather than dropping the new tab's refresh. Regression tests cover both lifecycle rules.

The [October 17 code structure review](code-structure-review.md) records the current boundaries, growth risks, and planned messaging placement. The [messaging schema](messaging-schema-proposal.md) is approved. The [messaging backend](messaging.md) adds private tables and a separate endpoint with command/projection modules; `_shared` contains Auth/HTTP and profile-photo primitives used by multiple server features. The iPhone messaging PR adds the Core service/state models, account-bound SDK adapter, conversation screens, and signed-in composition extraction. Account-keyed shell identity and state-generation checks reject late responses after leaving an account; SDK request ownership is checked before sending and after receiving. See [messaging](messaging.md) for refresh/retry behavior and device acceptance.

Connection reporting has its own Moderation feature across App, Core, and Supabase. It uses the existing account-bound Functions transport and shared Auth/HTTP helpers, rather than adding moderation commands to discovery or duplicating SDK clients. Review status and report records remain server-only; the app receives a receipt ID.
