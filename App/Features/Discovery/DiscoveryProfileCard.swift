import NewToTownCore
import SwiftUI

struct DiscoveryProfileCard: View {
    let profile: DiscoveryProfile
    var onDecision: ((ConnectionChoice) -> Void)? = nil

    var body: some View {
        ProfileCard(
            firstName: profile.firstName, jobTitle: profile.jobTitle,
            goal: profile.goal, city: profile.city, interests: profile.interests
        ) {
            RemoteProfilePhoto(url: profile.photoURL)
        } actions: {
            if let onDecision {
                DiscoveryDecisionButtons(name: profile.firstName, onDecision: onDecision)
            }
        }
    }
}
