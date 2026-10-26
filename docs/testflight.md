# TestFlight distribution

Both app variants use the same release process. Select the scheme and matching App Store Connect app before uploading.

| Variant | Xcode scheme | Archive configuration | Default bundle ID |
| --- | --- | --- | --- |
| Base app | NewToTown | Release | `com.newtotown.ios` |
| Test app | NewToTown Test | Release-Test | `com.newtotown.ios.test` |

The test variant uses the isolated `newtotown-test` backend and installs alongside the base app. Accounts and data are separate. See [test environment settings](test-environment.md).

## One-time setup for the test app

1. In [App Store Connect](https://appstoreconnect.apple.com/apps), create a separate iOS app record named **NewToTown Test**, using bundle ID `com.newtotown.ios.test` and a unique SKU such as `newtotown-ios-test`. If the ID is missing, register that explicit identifier under the same paid Apple Developer team used in Xcode.
2. Give the existing team members access to this new app under **Users and Access**. Access to the base app does not automatically imply access to the test app when a user's access is scoped to selected apps.
3. Under the new app's **TestFlight** tab, create an internal group named **Team**, add yourself and John, and enable automatic build distribution if desired. Each app has its own tester groups.

Internal testers must be App Store Connect users with access to the app. They install Apple's TestFlight app and accept the new app's invitation. No new Apple Developer membership or device registration is needed for a tester. See [Apple's internal tester instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).

## Each release

1. Use the reviewed, merged source and run the applicable checks. Xcode archives the files currently on disk, including uncommitted local edits; merging alone does not exclude them.
2. Select **NewToTown Test** in Xcode. Confirm the paid team, automatic signing, and bundle ID `com.newtotown.ios.test`. This scheme archives with **Release-Test**; Debug-only simulator fixtures are excluded.
3. Use a new build number for each upload to this app. The first upload can use `1`; later uploads must increase it. `Configuration/Base.xcconfig` supplies `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. The base and test App Store Connect records track their uploads separately.
4. Select **Any iOS Device (arm64)**, then **Product → Archive**.
5. In Organizer, choose **Distribute App → TestFlight Internal Only** and complete the upload for team testing. This follows the internal-testing release path used by the base app. Uploading does not publish an App Store release.
6. In App Store Connect, open **NewToTown Test → TestFlight**, wait for processing, and resolve any processing/compliance prompts. Add the build to **Team** if it was not assigned automatically.
7. Install or update **NewToTown Test** in TestFlight on each phone. Test matching and messaging with separate app accounts.

For future external testers, upload through **App Store Connect** distribution instead. A build uploaded as **TestFlight Internal Only** cannot be assigned to external groups. External testing requires TestFlight App Review and working reviewer sign-in instructions; see [Apple's external testing guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

Archives contain signed binaries and stay outside Git. Signing settings belong in ignored local configuration. Never commit signing certificates, private keys, or App Store Connect credentials.

The current app declares `ITSAppUsesNonExemptEncryption` as false for its existing system-networking and SDK implementation. Reassess that declaration if cryptography changes; see [Apple's system-encryption guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations).

## Device acceptance

Use two different app accounts on two phones:

- Complete sign-in, the first-signup agreement, profile details, and contact verification.
- Add/crop up to three photos, cycle the gallery, save, and check the unsaved-exit warning. Verify the direct × removal action.
- Open Discovery for both accounts, connect in both directions, and confirm the mutual connection. Check transition feel with Reduce Motion on and off.
- Send messages each way and refresh on the receiving phone. Background/foreground and switch accounts; previous-account conversations must not reappear.
- Report a disposable test connection and verify the intended exclusion after refresh. Use the normal deletion flow to remove disposable accounts.

Record the TestFlight version/build with bug reports. TestFlight builds expire after 90 days; upload replacements as needed. References: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
