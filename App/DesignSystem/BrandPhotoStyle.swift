import SwiftUI

/// Shared treatment for profile photos and private selfie previews.
private struct BrandPhotoStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: BrandTheme.ink.opacity(0.12), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func brandPhotoStyle() -> some View {
        modifier(BrandPhotoStyle())
    }
}
