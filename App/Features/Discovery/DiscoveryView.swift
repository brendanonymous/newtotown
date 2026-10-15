import NewToTownCore
import SwiftUI

struct DiscoveryView: View {
    let isSelected: Bool
    @State private var model: DiscoveryModel
    @State private var showsMatches = false
    @State private var blockTarget: DiscoveryProfile?
    @Environment(\.scenePhase) private var scenePhase

    init(service: any DiscoveryService, isSelected: Bool) {
        self.isSelected = isSelected
        _model = State(initialValue: DiscoveryModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let feed = model.feed {
                    visibilityControls(feed)
                    if feed.state == .ready {
                        Picker("Browse", selection: $showsMatches) {
                            Text("Discover").tag(false)
                            Text("Connections").tag(true)
                        }.pickerStyle(.segmented)
                        if showsMatches {
                            connections(feed.matches)
                        } else if let profile = feed.candidates.first {
                            DiscoveryProfileCard(profile: profile)
                            HStack(spacing: 32) {
                                decisionButton(.pass, symbol: "xmark", name: profile.firstName)
                                decisionButton(.connect, symbol: "checkmark", name: profile.firstName)
                            }.frame(maxWidth: .infinity)
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
                if model.isBusy { ProgressView("Please wait…") }
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red).font(.callout)
                }
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
        .navigationTitle("Scottsdale")
        .navigationBarTitleDisplayMode(.inline)
        .tint(BrandTheme.ink)
        .task(id: isSelected) {
            if isSelected { await model.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active { Task { await model.load() } }
        }
        .confirmationDialog("Block this profile?", isPresented: Binding(
            get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }
        ), titleVisibility: .visible) {
            if let profile = blockTarget {
                Button("Block \(profile.firstName)", role: .destructive) {
                    Task { await model.block(profile.id) }
                }
            }
        } message: { Text("You won’t see each other in discovery or connections.") }
    }

    @ViewBuilder private func visibilityControls(_ feed: DiscoveryFeed) -> some View {
        if !feed.visible && feed.state != .restricted {
            Text("Meet local friends.").font(.system(.title, design: .serif))
            Text("Joining shows your profile and photo to other members in Scottsdale. You can hide it at any time.")
                .foregroundStyle(BrandTheme.secondaryInk)
            Button("Join discovery") { Task { await model.setVisible(true) } }
                .buttonStyle(.borderedProminent).foregroundStyle(BrandTheme.background)
        }
    }

    private func connections(_ profiles: [DiscoveryProfile]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if profiles.isEmpty {
                Text("No connections yet.").font(.title2)
                Text("When you both tap the check, you’ll appear here.")
            } else {
                Text("You both connected.").font(.title2)
                Text("Messaging is coming next.").foregroundStyle(BrandTheme.secondaryInk)
                ForEach(profiles) { profile in
                    DiscoveryProfileCard(profile: profile)
                    Button("Block \(profile.firstName)", role: .destructive) { blockTarget = profile }
                    Divider()
                }
            }
        }
    }

    private func decisionButton(_ choice: ConnectionChoice, symbol: String, name: String) -> some View {
        Button { Task { await model.decide(choice) } } label: {
            Image(systemName: symbol).font(.title2.weight(.semibold))
                .frame(width: 64, height: 64)
                .foregroundStyle(choice == .connect ? BrandTheme.background : BrandTheme.ink)
                .background(choice == .connect ? BrandTheme.ink : BrandTheme.sage.opacity(0.3), in: Circle())
        }
        .accessibilityLabel(choice == .connect ? "Connect with \(name)" : "Pass on \(name)")
    }

    private func statusMessage(_ status: DiscoveryFeed.Status) -> String {
        switch status {
        case .hidden: "Your profile is hidden. Join when you’re ready."
        case .needsProfile: "Save your profile details first."
        case .needsPhoto: "Add your profile photo under My photos, then refresh."
        case .needsReview: "Your photos need approval before you can use discovery."
        case .restricted: "Discovery isn’t available for your account."
        case .ready: ""
        }
    }
}
