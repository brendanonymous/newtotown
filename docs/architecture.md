# Architecture

## Boundaries

Use native SwiftUI for this iPhone-only pilot. Group screens and their state by feature under `App/Features`. Put shared colors and reusable visual elements in `App/DesignSystem` only when they are shared.

Keep business rules independent of SwiftUI in `NewToTownCore`. The first rule validates HTTPS project URLs and publishable keys. Tests reject malformed endpoints and privileged-key formats; this is a configuration guard, not a substitute for server authorization.

When the backend is introduced, isolate Supabase calls behind feature-specific services. Views must not construct database queries. Add abstractions when a real integration or test requires them; avoid speculative base classes and generic repository layers.

## Configuration and data

The foundation makes no network requests. The Supabase project and key provided during setup have not been embedded or used to change the remote project. Backend wiring and SQL migrations belong in the authentication PR.

Only the project URL and publishable key may ship in the client. Database passwords, secret keys, and service-role keys must never enter the app bundle, Git, or logs. RLS policies and storage policies are mandatory before exposing user data.

Verification selfies will require private storage and a separate reviewer authorization boundary. A client-controlled flag must never grant reviewer access or approve a profile. Define retention, deletion, and consent before collecting selfies. Manual photo review does not verify legal identity, age, or background.

## UI

The supplied reference informs the palette, spacing, and restrained typography. It is a visual reference, not executable requirements. Text uses semantic font styles and scrollable layouts for Dynamic Type. The foundation intentionally uses a light appearance; dark mode is future work.

## Review

Keep PRs focused and document user-visible behavior, validation, and limitations. Test decisions and permission boundaries when implemented. Do not add snapshot tests that simply duplicate static layout. Never merge without owner review.
