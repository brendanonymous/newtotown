import NewToTownCore
import SwiftUI

struct ConnectionProfileView: View {
    @State private var model: ConnectionProfileModel
    @Environment(\.scenePhase) private var scenePhase

    init(conversationID: UUID, service: any MessagingService) {
        _model = State(initialValue: ConnectionProfileModel(conversationID: conversationID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let profile = model.profile {
                    DiscoveryProfileCard(profile: profile)
                        .accessibilityIdentifier("connectionProfile.card")
                }
                if model.isLoading { ProgressView("Loading profile…") }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar { BrandNavigationLogo() }
        .toolbar(.hidden, for: .tabBar)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await model.load() }
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
        .onDisappear { model.reset() }
        .privacySensitive()
    }
}
