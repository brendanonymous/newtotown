import SwiftUI

/// Shared monogram artwork used by the welcome screen and navigation headers.
struct BrandMark: View {
    var size: CGFloat = 116

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel("NewToTown")
    }
}

struct BrandNavigationLogo: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            BrandMark(size: 32)
        }
    }
}
