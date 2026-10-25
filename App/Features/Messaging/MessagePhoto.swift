import SwiftUI

struct MessagePhoto: View {
    let url: URL
    var body: some View {
        RemoteProfilePhoto(url: url, isAvatar: true)
        .frame(width: 48, height: 48).clipped()
        .background(BrandTheme.sage.opacity(0.2)).brandPhotoStyle()
        .accessibilityHidden(true)
    }
}
