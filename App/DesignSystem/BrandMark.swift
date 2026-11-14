import SwiftUI

/// Shared monogram artwork used by the welcome screen and navigation headers.
struct BrandMark: View {
    var size: CGFloat = 116

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
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
