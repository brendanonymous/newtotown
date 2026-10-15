import NewToTownCore
import SwiftUI

struct DiscoveryProfileCard: View {
    let profile: DiscoveryProfile

    var body: some View {
        ProfileCard(firstName: profile.firstName, jobTitle: profile.jobTitle,
                    goal: profile.goal, city: profile.city) {
            AsyncImage(url: profile.photoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    Label("Photo unavailable. Refresh to try again.", systemImage: "photo")
                        .font(.callout).padding()
                } else {
                    ProgressView()
                }
            }
        }
    }
}
