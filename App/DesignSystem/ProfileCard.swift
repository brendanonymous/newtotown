import SwiftUI

/// Identical public profile layout for the owner, discovery, and connections.
/// Callers provide their authorized photo source and keep actions outside the card.
struct ProfileCard<Photo: View>: View {
    let firstName: String
    let jobTitle: String
    let goal: String
    let city: String
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Constrain aspect-fill images to the available card width. Their
            // intrinsic width must not expand the scroll content past its margins.
            GeometryReader { geometry in
                photo()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: 300)
            .background(BrandTheme.sage.opacity(0.22))
            .brandPhotoStyle()
            Text(firstName).font(.system(.title, design: .serif))
            Label {
                Text(jobTitle).font(.headline)
            } icon: {
                Image(systemName: "briefcase").font(.caption)
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
            .accessibilityLabel("Occupation: \(jobTitle)")
            Label {
                Text(goal)
            } icon: {
                Image(systemName: "bubble.left").font(.caption)
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
            .accessibilityLabel("About me: \(goal)")
            Label(city, systemImage: "mappin").font(.footnote)
                .foregroundStyle(BrandTheme.secondaryInk)
        }
    }
}
