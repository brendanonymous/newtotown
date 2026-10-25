import NewToTownCore
import SwiftUI

struct DiscoveryView: View {
  let isSelected: Bool
  let reportedProfileIDs: Set<UUID>
  @State private var model: DiscoveryModel
  @State private var blockTarget: DiscoveryProfile?
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
            if let profile = feed.candidates.first {
              DiscoveryProfileCard(profile: profile) { choice in
                Task { await model.decide(choice) }
              }
              Button("Block this profile", role: .destructive) { blockTarget = profile }
            } else {
              Text("You’re caught up.").font(.title2)
              Text("More local friends will appear as people join. Check back soon.")
                .foregroundStyle(BrandTheme.secondaryInk)
            }
          } else {
            Text(statusMessage(feed.state)).foregroundStyle(BrandTheme.secondaryInk)
          }
        }
        if model.isBusy { ProgressView() }
        if let message = model.errorMessage {
          Text(message).foregroundStyle(.red).font(.callout)
          Button("Try again", systemImage: "arrow.clockwise") { Task { await model.load() } }
        }
      }
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
    .confirmationDialog(
      "Block this profile?",
      isPresented: Binding(
        get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }
      ), titleVisibility: .visible
    ) {
      if let profile = blockTarget {
        Button("Block \(profile.firstName)", role: .destructive) {
          Task { await model.block(profile.id) }
        }
      }
    } message: {
      Text("You won’t see each other in discovery, connections, or messages.")
    }
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
