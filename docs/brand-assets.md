# Brand assets and appearance

`Design/Brand` retains the owner's supplied developer pack: the full-bleed 4096-pixel PNG and editable SVG masters, transparent lettermark, and rounded presentation versions. The pack's README describes its provenance as a vector recreation of the selected design. These supplied assets supersede the earlier low-resolution screenshot; no glyph is redrawn by our export script.

Run `swift scripts/render-brand-assets.swift` from the repository root on macOS. It exports opaque 1024 × 1024 default, dark and tinted app icons. The default uses the full-bleed master; dark uses the supplied transparent lettermark over brand ink; tinted uses that same mark on a grayscale background. Rounded presentation files are retained as design sources, not baked into the iOS icon. iOS supplies the icon mask.

The same default/dark exports supply `BrandLogo`, used by welcome artwork and signed-in navigation. The landing page omits the centered navigation logo; the pilot overview keeps it. `BrandTheme` follows the pack's ivory `#FAF5EF` and sage `#A8AD8F`, with semantic foreground/background colors for dark appearance. The app follows the device appearance; iOS versions without alternate icon appearances use the default icon. No extra image dependency is introduced.

Commit source assets, export script and generated assets together. Keep only render-ready images in the asset catalog; editable source artwork stays in `Design/Brand`. The normal app's display name is **NewToTown** and the separate test app is **NewToTown Test**. Install a new build to see updated icon/name artwork. App Store Connect's listing name is separate.

## Action buttons

`BrandActionButtonStyle` centralizes filled and secondary action buttons in
signup, profile editors, photos, interests, contacts, preferences, Discovery, and
the chat composer. Buttons size to their labels with a minimum 44-point touch
height; entry/signup actions can explicitly fill the available width. Both tones
use `BrandTheme.buttonCornerRadius` (16 points), a continuous rounded rectangle,
and shared pressed/disabled feedback. Discovery's fixed-size decision controls
use the same corner radius. Native navigation, alerts, menus, and photo controls
keep their specialized behavior.
