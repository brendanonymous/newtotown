import NewToTownCore
import SwiftUI

struct DiscoveryProfileCard: View {
    let profile: DiscoveryProfile
    var pendingDecision: ConnectionChoice? = nil
    var onDecision: ((ConnectionChoice) -> Void)? = nil

    var body: some View {
        ProfileCard(
            firstName: profile.firstName, jobTitle: profile.jobTitle,
            goal: profile.goal, city: profile.city, interests: profile.interests
        ) {
            ProfilePhotoGallery(count: profile.photoURLs.count) { index in
                RemoteProfilePhoto(url: profile.photoURLs[index])
            }
            .id(profile.id)
        } actions: {
            if let onDecision {
                DiscoveryDecisionButtons(
                    name: profile.firstName, pendingDecision: pendingDecision, onDecision: onDecision)
            }
        }
    }
}
