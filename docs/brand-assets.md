# Brand assets

The supplied logo reference is recreated as a sage/ivory vector monogram. `scripts/render-brand-assets.swift` is the editable source for both outputs in `App/Assets.xcassets`:

- `BrandLogo.imageset/BrandLogo.pdf`: vector artwork used by `BrandMark` on the welcome screen and navigation headers.
- `AppIcon.appiconset/AppIcon.png`: opaque 1024 × 1024 image. iOS supplies the icon mask; the asset does not include screenshot labels, baked-in rounded corners, or exterior shadows.

From the repository root on macOS, run `swift scripts/render-brand-assets.swift` to regenerate both files. Commit the script and generated assets together. `Configuration/Base.xcconfig` selects `AppIcon`; no personal signing settings or Xcode project formatting changes are needed.

Build/install the app to update the home-screen icon. Validate the logo in welcome, signup, signed-in tabs, and the photo screen. The shared monogram has a spoken app-name label for VoiceOver.
