# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared.

Keep business rules independent of SwiftUI in `NewToTownCore`. Rules validate HTTPS project URLs, publishable keys, profile field limits, the 18+ boundary, and platonic agreement. Tests reject malformed endpoints and privileged-key formats; this is a configuration guard, not a substitute for server authorization.

Supabase calls live in `SupabaseOnboardingService`, behind `OnboardingService`. `OnboardingModel` owns transitions, loading, and retryable errors; SwiftUI views render it. Views do not construct database queries. Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The signup PR embeds public connection values through build configuration. It uses the pinned official Supabase Swift SDK for email OTP, Keychain session persistence, refresh, and profile queries. The SQL migration and policy tests are versioned under `supabase/`. Hosted schema changes are not applied automatically.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Verification selfies will require private storage and a separate reviewer authorization boundary. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.
