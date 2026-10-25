import NewToTownCore
import SwiftUI

/// Identical public profile layout for the owner, discovery, and connections.
/// Callers provide their authorized photo source and an optional dedicated action column.
struct ProfileCard<Photo: View, Actions: View>: View {
    let firstName: String
    let jobTitle: String
    let goal: String
    let city: String
    var interests: [ProfileInterest] = []
    @ViewBuilder var photo: () -> Photo
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(firstName).font(.system(.title, design: .serif))
            ProfilePhotoFrame { photo() }
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
                    if !interests.isEmpty { InterestTags(interests: interests) }
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
        firstName: String, jobTitle: String, goal: String, city: String, interests: [ProfileInterest] = [],
        @ViewBuilder photo: @escaping () -> Photo
    ) {
        self.init(
            firstName: firstName, jobTitle: jobTitle, goal: goal, city: city, interests: interests,
            photo: photo, actions: { EmptyView() })
    }
}
