import NewToTownCore
import SwiftUI

/// Identical public profile layout for the owner, discovery, and connections.
/// Callers provide framed photo content (including any indicators below it)
/// and an optional dedicated action column.
struct ProfileCard<Photo: View, Actions: View>: View {
    let firstName: String
    var age: Int? = nil
    let jobTitle: String
    let goal: String
    let city: String
    var interests: [ProfileInterest] = []
    @ViewBuilder var photo: () -> Photo
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(firstName).font(.system(.title, design: .serif))
                if let age {
                    Text(age, format: .number)
                        .font(.system(.title, design: .serif))
                        .accessibilityLabel("Age: \(age)")
                        .accessibilityIdentifier("profile.age")
                }
            }
            photo()
            Label(city, systemImage: "mappin").font(.footnote).foregroundStyle(BrandTheme.secondaryInk)
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
        firstName: String, age: Int? = nil, jobTitle: String, goal: String, city: String,
        interests: [ProfileInterest] = [], @ViewBuilder photo: @escaping () -> Photo
    ) {
        self.init(
            firstName: firstName,
            age: age,
            jobTitle: jobTitle,
            goal: goal,
            city: city,
            interests: interests,
            photo: photo,
            actions: { EmptyView() })
    }
}
