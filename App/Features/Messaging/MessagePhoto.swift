import SwiftUI

struct MessagePhoto: View {
    let url: URL
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.square").foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        .frame(width: 48, height: 48).clipped()
        .background(BrandTheme.sage.opacity(0.2)).brandPhotoStyle()
        .accessibilityHidden(true)
    }
}
