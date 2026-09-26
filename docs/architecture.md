# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared.

`NewToTownCore` contains profile rules, the onboarding model, and its service interface. It has no SwiftUI or Supabase dependency. `NewToTownSupabase` depends on the core and the official SDK; it contains the concrete service and public connection configuration. Configuration tests reject malformed endpoints and privileged-key formats, but server authorization still relies on RLS.

`NewToTownApp` reads configuration and owns the onboarding model. Views receive that model instead of creating backend clients. The welcome preview passes no model and makes no backend connection. The dependency direction is `App → NewToTownSupabase → NewToTownCore`, with views also importing the core directly.

Supabase calls live in `SupabaseOnboardingService`, behind `OnboardingService`. `OnboardingModel` owns transitions, loading, and retryable errors; SwiftUI views render it. Views do not construct database queries. Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The signup PR embeds public connection values through build configuration. It uses the pinned official Supabase Swift SDK for email OTP, Keychain session persistence, refresh, and profile queries. The SQL migration and policy tests are versioned under `supabase/`. Hosted schema changes are not applied automatically.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Verification selfies will require private storage and a separate reviewer authorization boundary. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.
