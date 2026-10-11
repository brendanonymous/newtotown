# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared.

`NewToTownCore` contains profile rules, onboarding/photo/discovery models, typed photo requirements, and service interfaces. It has no SwiftUI or Supabase dependency. `NewToTownSupabase` depends on the core and the official SDK; it contains the concrete service and public connection configuration. Configuration tests reject malformed endpoints and privileged-key formats, but server authorization still relies on RLS.

`NewToTownApp` reads configuration and owns the onboarding model. Views receive that model instead of creating backend clients. The welcome preview passes no model and makes no backend connection. The dependency direction is `App → NewToTownSupabase → NewToTownCore`, with views also importing the core directly. Feature screens own transient photo/discovery state. Saved accounts render `ProfileHomeView` with native Profile/Settings tabs; `ProfileSettingsView` owns its visibility model, while account mutations remain in onboarding.

Supabase calls live in the onboarding, photo, and discovery services, behind their core interfaces. `SupabaseServices` shares one client/session between them. `OnboardingModel` owns transitions, loading, and retryable errors; SwiftUI views render it. Views do not construct database queries. `FirstSignupIntroduction` presents the one-time slides; `OnboardingModel` advances only after the account-level acceptance is persisted. See [onboarding agreement](onboarding-agreement.md). Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The signup PR embeds public connection values through build configuration. It uses the pinned official Supabase Swift SDK for email OTP, Keychain session persistence, refresh, and profile queries. The SQL migration and policy tests are versioned under `supabase/`. Hosted schema changes are not applied automatically.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Selfies use owner-only private storage. The server-owned [photo-review flag](photo-review-flag.md) controls collection and eligibility requirements; reviewer authorization remains separate work. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

Discovery uses a separate authenticated Edge Function for public profile projection and short-lived profile-photo links. It shares photo-review eligibility with the flag feature and keeps private profile rows and selfies behind their existing owner policies; see [discovery](discovery.md).

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.
