# Isolated testing environment

Select **NewToTown Test** in Xcode to run or archive against the separate testing backend. The regular **NewToTown** scheme keeps its existing backend. Both use the same app target and source code; environment-specific build configurations avoid duplicate targets.

## Configure once

1. Create a separate Supabase project named `newtotown-test`. Apply the repository's migrations to this fresh project and deploy `delete-account`, `discovery`, `messaging`, `reports`, and (after its migration) `interests`, keeping JWT validation enabled. Never copy production accounts, photos, or server secrets into testing.
2. `Configuration/Test.Public.xcconfig` selects the separate test project using public connection values. To use a different test project, copy `Configuration/Test.Local.xcconfig.example` to `Configuration/Test.Local.xcconfig` and override them. That file is ignored by Git. Use the dashboard for server credentials.
3. Configure Auth separately: email/SMS providers, sender credentials, templates, rate limits, and allowed redirect URLs are project settings and do not follow database migrations. See `backend-setup.md` and `phone-sign-in.md`. Test email codes work independently of Twilio once email delivery is configured.
4. Select **NewToTown Test**, select an iPhone, and Run. Its default bundle ID is `com.newtotown.ios.test` and its home-screen name is **newtotown Test**. Accounts and Keychain access are separate from the regular app because the app identities differ. Sign in again against the new project.

Test settings explicitly replace the normal scheme's backend defaults with the test project before loading any optional test override. Do not point the test override at the live project. `Local.xcconfig` still supplies personal signing settings; the test configuration overrides its normal bundle ID. If needed, set a unique test bundle ID in `Test.Local.xcconfig`.

## TestFlight

Create a separate App Store Connect app using the test bundle ID if distributing this variant through TestFlight. Archive **NewToTown Test** (uses `Release-Test`), verify the bundle ID/name, and upload to that app's internal testing group. Both variants can be installed at once. The backend is selected at build time: changing it requires rebuilding/reinstalling or uploading a new TestFlight build. Keep version/build numbers unique within each App Store Connect app.

The separate project is `newtotown-test` (`acmrnolvakubxnaxwpzt`). Only its host and publishable key are checked in; no administrative credentials ship in the app. Auth setup, device signing, and the separate TestFlight app must be configured before hosted end-to-end testing. Seed fictional profiles only into this isolated project; see the seed tooling instructions once available.
