import NewToTownCore
import SwiftUI

struct DiscoveryProfileCard: View {
    let profile: DiscoveryProfile

    var body: some View {
        ProfileCard(firstName: profile.firstName, jobTitle: profile.jobTitle,
                    goal: profile.goal, city: profile.city) {
            RemoteProfilePhoto(url: profile.photoURL)
        }
    }
}
