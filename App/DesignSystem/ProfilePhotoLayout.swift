import SwiftUI

/// The existing 300-point viewport is shared by profile cards, previews, and cropping.
enum ProfilePhotoLayout {
    static let height: CGFloat = 300
}

struct ProfilePhotoFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            content().frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .frame(height: ProfilePhotoLayout.height)
        .background(BrandTheme.sage.opacity(0.22))
        .brandPhotoStyle()
    }
}
