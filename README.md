# newtotown

An iPhone app for platonic friendship among men, starting in Scottsdale, Arizona (18+).

## Current build

The app supports email-code signup/sign-in and private profile details. It retains the sage and warm-white welcome screen and pilot overview. Photo verification, discovery, matching, messaging, and account deletion are not implemented yet. The N remains a temporary typographic mark.

See [backend setup and phone journeys](docs/backend-setup.md) before testing live signup. The hosted Supabase project still needs the migration and email settings; this PR does not apply them automatically.

## Run

1. Install Xcode 16 or newer (validated locally with Xcode 26.4).
2. Open `NewToTown.xcodeproj`.
3. Select the **NewToTown** scheme and an iPhone simulator, then press Run.

The app targets iOS 17+. No paid membership is needed for simulator use. Public backend settings are included; live signup also needs the documented Supabase setup.

For a physical iPhone, copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig`, enter your Team ID and an available bundle identifier, then select the connected phone in Xcode. Local configuration is ignored by Git. TestFlight distribution requires an active Apple Developer membership and later release configuration, including an app icon.

## Check

```sh
swift test
xcodebuild -project NewToTown.xcodeproj -scheme NewToTown \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Swift Package tests validate configuration, profile rules, and onboarding transitions using a test service that sends no email. The Xcode build validates the iPhone UI. CI also runs the signup-entry UI test on an iPhone simulator and PostgreSQL access-policy tests. No production credentials are required.

## Code map

- `App/`: app entry point, shared design tokens, and feature screens.
- `Sources/NewToTownCore/`: profile rules, onboarding state, and service interfaces without a backend dependency.
- `Sources/NewToTownSupabase/`: Supabase integration and public connection configuration. Created by the app entry point, not feature views.
- `Tests/`: core behavior tests.
- `Configuration/`: shared build settings and a local signing example.
- `docs/`: architecture and implementation scope.

See [architecture](docs/architecture.md) and [delivery plan](docs/delivery-plan.md).
