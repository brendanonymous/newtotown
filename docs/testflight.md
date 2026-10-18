# TestFlight distribution

TestFlight distributes the Release app to iPhones without pairing each device with Xcode. This first beta includes the messaging changes in PR #12; that PR remains a separate review.

## App Store Connect setup (once)

Use the same paid Apple Developer team selected in Xcode. In [App Store Connect](https://appstoreconnect.apple.com/apps), choose **Apps → + → New App**:

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | newtotown (subject to availability) |
| Primary language | English (U.S.) |
| Bundle ID | `com.newtotown.ios` |
| SKU | `newtotown-ios` |
| User access | Full access for the owner |

If the bundle ID is missing, register that exact explicit identifier in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list). Do not change it between uploads. Accept any outstanding Apple agreements using the account holder's login.

## Archive and upload

1. Open `NewToTown.xcodeproj`. Confirm the NewToTown target uses your paid team and automatic signing. Local signing settings belong in ignored `Configuration/Local.xcconfig`.
2. Keep the marketing version at `0.1.0` for this beta. Set `CURRENT_PROJECT_VERSION` in `Configuration/Base.xcconfig` to a new build number for each upload (first candidate: `1`). Do not reuse an uploaded number.
3. Select the NewToTown scheme and **Any iOS Device (arm64)**, then **Product → Archive**. The shared scheme archives with Release configuration; simulator journey fixtures compile only in Debug.
4. In Organizer, choose **Distribute App → App Store Connect** and upload with automatic signing. Use the normal App Store Connect distribution option so the build can later be submitted for external testing. Uploading a build does not publish it on the App Store.
5. Wait for processing, then open the app's **TestFlight** tab in App Store Connect. Resolve any processing or compliance messages before assigning testers.

The app uses Apple's system networking, Security, and CryptoKit through its SDK dependencies. `ITSAppUsesNonExemptEncryption` is false for this implementation, following [Apple's system-encryption guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations). Reassess this declaration if adding custom cryptography or changing these dependencies.

A terminal archive uses the same signing account already added to Xcode:

```sh
xcodebuild -project NewToTown.xcodeproj -scheme NewToTown \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/newtotown-testflight/NewToTown-0.1.0-1.xcarchive \
  -allowProvisioningUpdates archive
open /tmp/newtotown-testflight/NewToTown-0.1.0-1.xcarchive
```

Change the archive path/version/build together for subsequent candidates. Archives contain signed binaries and stay outside Git. Never commit signing certificates, private keys, or App Store Connect credentials.

## Testers

Start with an internal group named **Device QA**, add the owner as a tester, and assign the processed build. Internal testers must be App Store Connect users with app access; do not give ordinary pilot participants developer-account access just to test. Install Apple's TestFlight app on each device, accept the invitation, and install newtotown.

For friends or pilot participants, create an external group named **Scottsdale Pilot**. Supply beta description, feedback email, review contact, and working review access, then submit the build for TestFlight App Review. Once approved, invite the intended testers by email or enable a controlled public link. Each participant should sign in with their own app account when testing matching and messaging. Signing into the same account on two phones does not simulate two participants.

Email OTP requires access to the recipient inbox. Before external review, arrange an Apple-review-accessible sign-in path and document it in review notes; do not assume a reviewer can access the owner's email. There is no authentication bypass in the app.

TestFlight uses the live backend and stores real profiles, photos, connections, and messages. Test account deletion removes data through the normal app flow. Builds expire after 90 days; upload replacements as needed. Testers do not need a paid developer membership.

## Device acceptance

Use two different app accounts on two phones:

- Complete email-code sign-in, the first-signup agreement, profile details, and photo upload.
- Enable discovery for both; connect in both directions and confirm the mutual connection.
- Open Messages, send each way, and pull to refresh on the receiving phone. Live delivery and push notifications are not implemented yet.
- Background/foreground, sign out/in, and confirm no conversation from another account appears.
- Block the other participant; confirm the conversation is unavailable on both phones after refresh.

Record the TestFlight version/build with any bug report. Run the existing Swift tests, Release archive, and simulator journeys before each candidate; the device exercise adds real signing, network, and cross-account coverage.

References: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [external testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).
