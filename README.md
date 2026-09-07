# newtotown

An iPhone app for platonic friendship among men, starting in Scottsdale, Arizona (18+).

## Current build

The foundation contains a SwiftUI welcome screen and pilot overview using the sage and warm-white visual direction. It does **not** create accounts, upload photos, verify people, match users, or send messages. No sample users are presented as real people. The letter N is a temporary typographic mark, not the final supplied monogram.

## Run

1. Install Xcode 16 or newer (validated locally with Xcode 26.4).
2. Open `NewToTown.xcodeproj`.
3. Select the **NewToTown** scheme and an iPhone simulator, then press Run.

The app targets iOS 17+. No paid membership or backend credentials are needed for simulator use.

For a physical iPhone, copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig`, enter your Team ID and an available bundle identifier, then select the connected phone in Xcode. Local configuration is ignored by Git. TestFlight distribution requires an active Apple Developer membership and later release configuration, including an app icon.

## Check

```sh
swift test
xcodebuild -project NewToTown.xcodeproj -scheme NewToTown \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Swift Package tests validate public backend configuration without network access. The Xcode build validates the iPhone UI. CI runs both on macOS; no credentials are required.

## Code map

- `App/`: app entry point, shared design tokens, and feature screens.
- `Sources/NewToTownCore/`: platform-independent logic, tested with Swift Package Manager. Not linked into the UI until backend integration needs it.
- `Tests/`: core behavior tests.
- `Configuration/`: shared build settings and a local signing example.
- `docs/`: architecture and implementation scope.

See [architecture](docs/architecture.md) and [delivery plan](docs/delivery-plan.md).
