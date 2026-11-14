import NewToTownCore
import SwiftUI

/// Owns presentation between acknowledged decisions; networking stays in DiscoveryModel.
struct DiscoveryDeck: View {
    let profile: DiscoveryProfile?
    let pendingDecision: ConnectionChoice?
    let reduceMotion: Bool
    let onDecision: (ConnectionChoice, UUID) -> Void
    @State private var displayedProfile: DiscoveryProfile?
    @State private var lastChoice = ConnectionChoice.connect
    @State private var isTransitioning = false
    @State private var transitionID = UUID()

    init(
        profile: DiscoveryProfile?, pendingDecision: ConnectionChoice?, reduceMotion: Bool,
        onDecision: @escaping (ConnectionChoice, UUID) -> Void
    ) {
        self.profile = profile
        self.pendingDecision = pendingDecision
        self.reduceMotion = reduceMotion
        self.onDecision = onDecision
        _displayedProfile = State(initialValue: profile)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let displayedProfile {
                DiscoveryProfileCard(profile: displayedProfile, pendingDecision: pendingDecision) { choice in
                    guard !isTransitioning, pendingDecision == nil else { return }
                    lastChoice = choice
                    onDecision(choice, displayedProfile.id)
                }
                .id(displayedProfile.id)
                // Keep the departing card above the background and animate it as one layer.
                .compositingGroup()
                .zIndex(1)
                .transition(
                    reduceMotion
                        ? .identity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .offset(x: lastChoice == .connect ? -48 : 48)),
                            removal: .opacity.combined(with: .offset(x: lastChoice == .connect ? 48 : -48))))
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Text("You’re caught up.").font(.title2)
                    Text("More local friends will appear as people join. Check back soon.")
                        .foregroundStyle(BrandTheme.secondaryInk)
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .disabled(isTransitioning)
        .onChange(of: profile) { _, next in show(next) }
    }

    private func show(_ next: DiscoveryProfile?) {
        // Refreshing the same person renews their data without replaying the transition.
        guard displayedProfile?.id != next?.id else {
            displayedProfile = next
            return
        }
        let id = UUID()
        transitionID = id
        guard !reduceMotion else {
            displayedProfile = next
            isTransitioning = false
            return
        }
        isTransitioning = true
        withAnimation(.smooth(duration: 0.55), completionCriteria: .removed) {
            displayedProfile = next
        } completion: {
            // A refresh can replace a transition before its completion runs.
            if transitionID == id { isTransitioning = false }
        }
    }
}
