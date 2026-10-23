import NewToTownCore
import SwiftUI

/// Mutual connections that have not yet started a conversation.
struct ConnectionsView: View {
    let accountID: UUID
    let messagingService: (any MessagingService)?
    let reportingService: (any ProfileReportingService)?
    let isSelected: Bool
    @State private var model: DiscoveryModel
    @State private var chatTarget: ConversationTarget?
    @State private var reportTarget: DiscoveryProfile?
    @Environment(\.scenePhase) private var scenePhase

    init(
        service: any DiscoveryService, accountID: UUID,
        messagingService: (any MessagingService)?, reportingService: (any ProfileReportingService)?,
        isSelected: Bool
    ) {
        self.accountID = accountID
        self.messagingService = messagingService
        self.reportingService = reportingService
        self.isSelected = isSelected
        _model = State(initialValue: DiscoveryModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Connections").font(.system(.largeTitle, design: .serif))
                    .accessibilityIdentifier("connections.title")
                if let feed = model.feed {
                    if feed.matches.isEmpty {
                        Text("No connections yet.").font(.title2)
                        Text("When you both tap the check, you’ll appear here.")
                            .foregroundStyle(BrandTheme.secondaryInk)
                    }
                    ForEach(feed.matches) { profile in
                        DiscoveryProfileCard(profile: profile)
                        if messagingService != nil {
                            Button {
                                chatTarget = .peer(profile.id)
                            } label: {
                                Label("Message \(profile.firstName)", systemImage: "bubble.left")
                            }
                        }
                        if reportingService != nil {
                            Button("Report \(profile.firstName)", systemImage: "flag") {
                                reportTarget = profile
                            }
                        }
                        Divider()
                    }
                }
                if model.isBusy { ProgressView("Loading connections…") }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await model.load() }
        // Returning from a chat must reconcile sends/blocks, including lost responses.
        .task(id: isSelected && chatTarget == nil) {
            if isSelected && chatTarget == nil { await model.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && chatTarget == nil && phase == .active { Task { await model.load() } }
        }
        .navigationDestination(item: $chatTarget) { target in
            if let messagingService {
                ChatView(accountID: accountID, target: target, service: messagingService)
            }
        }
        .sheet(item: $reportTarget) { profile in
            if let reportingService { ReportProfileView(profile: profile, service: reportingService) }
        }
        .privacySensitive()
    }
}
