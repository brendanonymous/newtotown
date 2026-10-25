# Official brand assets

The approved artwork is the owner's supplied `IMG_1029.png`, retained byte-for-byte as `App/Assets.xcassets/BrandLogo.imageset/BrandLogo.png`. Both the shared in-app `BrandMark` and the home-screen icon now use this artwork. The old vector approximation has been removed.

The source is 683 × 656 pixels and includes an alpha channel. `scripts/render-brand-assets.swift` crops only the side background to a square, preserves the mark's proportions, scales to 1024 × 1024 and exports an opaque PNG into `AppIcon.appiconset/AppIcon.png`. The original image remains unchanged. iOS supplies the icon's rounded mask; no corner rounding or outer shadow is baked into the exported asset. `BrandMark` uses aspect fill and its existing rounded clip for consistent in-app presentation.

From the repository root on macOS:

```sh
swift scripts/render-brand-assets.swift
```

Commit the approved source, script and generated icon together. A higher-resolution original of the same design would improve sharpness: exporting this source at 1024 pixels enlarges it without creating additional detail. Replace the source only with owner-approved artwork, then regenerate the icon.

The regular scheme displays **NewToTown** under the icon. The separate test scheme displays **NewToTown Test**. Build and reinstall the desired scheme to update its installed name and icon; existing TestFlight installations need a new uploaded build. App Store Connect's product-page name is configured separately.

Validate the artwork on the home screen, welcome/signup screens and signed-in navigation headers. The shared logo retains the VoiceOver label “NewToTown.” Apple documents asset-catalog setup at https://developer.apple.com/documentation/xcode/configuring-your-app-icon.
