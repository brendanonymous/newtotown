import SwiftUI

/// Identical public profile layout for the owner, discovery, and connections.
/// Callers provide their authorized photo source and an optional dedicated action column.
struct ProfileCard<Photo: View, Actions: View>: View {
    let firstName: String
    let jobTitle: String
    let goal: String
    let city: String
    @ViewBuilder var photo: () -> Photo
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(firstName).font(.system(.title, design: .serif))
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
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .accessibilityIdentifier("profile.details")
                actions().fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

extension ProfileCard where Actions == EmptyView {
    init(
        firstName: String, jobTitle: String, goal: String, city: String,
        @ViewBuilder photo: @escaping () -> Photo
    ) {
        self.init(
            firstName: firstName, jobTitle: jobTitle, goal: goal, city: city,
            photo: photo, actions: { EmptyView() })
    }
}
