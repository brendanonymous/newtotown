# Brand assets and appearance

`Design/Brand` contains the corrected developer package's highest-resolution PNG masters: the square and transparent rounded versions at 8192 × 8192 pixels. Their bytes are preserved exactly. The package README notes these are upscales of a 1254-pixel original, rather than additional native detail. The supplied SVG tracings are retained for editing, with malformed duplicate `rect` tokens repaired; their approximated shading differs from the PNG, so the PNGs are the production source.

Run `swift scripts/render-brand-assets.swift` from the repository root on macOS. It downsamples the masters into two 1024 × 1024 sRGB assets: an opaque `AppIcon` from the square master and a transparent `BrandLogo` from the rounded master. Only these exports enter the app bundle. iOS applies its home-screen icon mask; `BrandMark` displays the rounded logo with aspect fit and no additional corner clipping.

The package supplies one logo appearance. The app uses that corrected artwork in both light and dark mode; previous dark/tinted artwork has been removed. iOS handles its tinted-icon appearance from the current default icon. Install a new build to see the updated home-screen icon.

The supplied SVG defines the palette:

| Color | Hex | App use |
| --- | --- | --- |
| Light sage | `#BEC5AC` | Gradient reference and dark-mode secondary text |
| Mid sage | `#B5BEA6` | Shared accent and translucent control surfaces |
| Deep sage | `#A7AF98` | Gradient reference; retained in the supplied artwork |
| Warm white | `#FBF8F4` | Light background and dark-mode primary text |

`BrandTheme` retains contrasting ink (`#293B30`), secondary ink (`#596653`), and dark surfaces. The app follows the device appearance. `BrandMark` draws the shared image, `BrandNavigationLogo` positions it in the navigation bar, and each screen or its parent adds `.toolbar { BrandNavigationLogo() }`. The welcome screen places a larger `BrandMark` directly in its content.

Commit the masters, export script, and generated assets together. The normal app's display name is **NewToTown** and the separate test app is **NewToTown Test**. App Store Connect's listing name is separate.

## Action buttons

`BrandActionButtonStyle` centralizes filled and secondary action buttons in
signup, profile editors, photos, interests, contacts, preferences, Discovery, and
the chat composer. Buttons size to their labels with a minimum 44-point touch
height; entry/signup actions can explicitly fill the available width. Both tones
use `BrandTheme.buttonCornerRadius` (16 points), a continuous rounded rectangle,
and shared pressed/disabled feedback. Discovery's fixed-size decision controls
use the same corner radius. Native navigation, alerts, menus, and photo controls
keep their specialized behavior.

## Connections icon

`Handshake.imageset` uses the supplied Font Awesome Free 7.3.1 solid handshake SVG. Its original paths and embedded copyright/license notice are preserved; only a 30-point intrinsic canvas size is added to balance its padded artwork with the adjacent system symbols. The asset keeps vector representation and template rendering, so the tab bar supplies its selected/unselected tint in light and dark appearance. No icon package is required. Source: [Font Awesome Handshake Solid](https://fontawesome.com/icons/classic/solid/handshake?style=solid); [Font Awesome Free license](https://fontawesome.com/license/free).
