import NewToTownCore
import SwiftUI

struct DiscoveryView: View {
    let isSelected: Bool
    let reportedProfileIDs: Set<UUID>
    @State private var model: DiscoveryModel
    @State private var lastChoice = ConnectionChoice.connect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(service: any DiscoveryService, isSelected: Bool, reportedProfileIDs: Set<UUID>) {
        self.isSelected = isSelected
        self.reportedProfileIDs = reportedProfileIDs
        _model = State(initialValue: DiscoveryModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let feed = model.feed {

                    visibilityControls(feed)

                    if feed.state == .ready {
                        discoveryDeck(feed)
                    } else {
                        Text(statusMessage(feed.state)).foregroundStyle(BrandTheme.secondaryInk)
                    }
                }
                if model.isBusy && model.pendingDecision == nil { ProgressView() }
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red).font(.callout)
                    Button("Try again", systemImage: "arrow.clockwise") { Task { await model.load() } }
                }
            }
            .background { DiscoveryPhotoPreloader(url: nextPhotoURL) }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await model.load() }
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
        .tint(BrandTheme.ink)
        .task(id: isSelected) {
            model.excludeProfiles(reportedProfileIDs)
            if isSelected { await model.load() }
        }
        .onChange(of: reportedProfileIDs) { _, ids in
            model.excludeProfiles(ids)
            Task { await model.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active { Task { await model.load() } }
        }

    }

    private var nextPhotoURL: URL? {
        guard isSelected, let feed = model.feed, feed.state == .ready else { return nil }
        return feed.candidates.dropFirst().first?.photoURL
    }

    private func discoveryDeck(_ feed: DiscoveryFeed) -> some View {
        ZStack(alignment: .topLeading) {
            if let profile = feed.candidates.first {
                DiscoveryProfileCard(profile: profile, pendingDecision: model.pendingDecision) { choice in
                    lastChoice = choice
                    Task { await model.decide(choice, on: profile.id) }
                }
                .id(profile.id)
                .transition(
                    reduceMotion
                        ? .identity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .offset(x: lastChoice == .connect ? -48 : 48)),
                            removal: .opacity.combined(with: .offset(x: lastChoice == .connect ? 72 : -72))))
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Text("You’re caught up.").font(.title2)
                    Text("More local friends will appear as people join. Check back soon.")
                        .foregroundStyle(BrandTheme.secondaryInk)
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: feed.candidates.first?.id)
    }

    @ViewBuilder private func visibilityControls(_ feed: DiscoveryFeed) -> some View {
        if !feed.visible && feed.state != .restricted {
            Text("Meet local friends.").font(.system(.title, design: .serif))
            Text("Joining shows your profile and photo to others. You can hide it at any time.")
                .foregroundStyle(BrandTheme.secondaryInk)
            Button("Join discovery") { Task { await model.setVisible(true) } }
                .buttonStyle(.borderedProminent).foregroundStyle(BrandTheme.background)
        }
    }

    private func statusMessage(_ status: DiscoveryFeed.Status) -> String {
        switch status {
        case .hidden: ""
        case .needsProfile: "Save your profile details first."
        case .needsPhoto: "Add your profile photo under My photos, then pull down to refresh."
        case .needsReview: "Your photos need approval before you can use discovery."
        case .restricted: "Discovery isn’t available for your account."
        case .ready: ""
        }
    }
}
