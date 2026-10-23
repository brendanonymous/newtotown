import NewToTownCore
import SwiftUI

/// Mutual connections that have not yet started a conversation.
struct ConnectionsView: View {
    let accountID: UUID
    let messagingService: (any MessagingService)?
    let reportingService: (any ProfileReportingService)?
    let isSelected: Bool
    let reportedProfileIDs: Set<UUID>
    let onReportSubmitted: (UUID) -> Void
    @State private var model: DiscoveryModel
    @State private var chatTarget: ConversationTarget?
    @State private var reportTarget: DiscoveryProfile?
    @Environment(\.scenePhase) private var scenePhase

    init(
        service: any DiscoveryService,
        accountID: UUID,
        messagingService: (any MessagingService)?,
        reportingService: (any ProfileReportingService)?,
        isSelected: Bool, reportedProfileIDs: Set<UUID>,
        onReportSubmitted: @escaping (UUID) -> Void
    ) {
        self.accountID = accountID
        self.messagingService = messagingService
        self.reportingService = reportingService
        self.isSelected = isSelected
        self.reportedProfileIDs = reportedProfileIDs
        self.onReportSubmitted = onReportSubmitted
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
                                Label("Message", systemImage: "bubble.left")
                            }
                            .accessibilityLabel("Message \(profile.firstName)")
                        }
                        if reportingService != nil {
                            Button("Report", systemImage: "flag") {
                                reportTarget = profile
                            }
                            .accessibilityLabel("Report \(profile.firstName)")
                        }
                        Divider()
                    }
                }
                if model.isBusy { ProgressView() }
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
            model.excludeProfiles(reportedProfileIDs)
            if isSelected && chatTarget == nil { await model.load() }
        }
        .onChange(of: reportedProfileIDs) { _, ids in
            model.excludeProfiles(ids)
            if ids.contains(where: { chatTarget == .peer($0) }) { chatTarget = nil }
            Task { await model.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && chatTarget == nil && phase == .active { Task { await model.load() } }
        }
        .navigationDestination(item: $chatTarget) { target in
            if let messagingService {
                ChatView(
                    accountID: accountID, target: target, messagingService: messagingService,
                    reportingService: reportingService, reportedProfileIDs: reportedProfileIDs,
                    onReportSubmitted: onReportSubmitted)
            }
        }
        .sheet(item: $reportTarget, onDismiss: { Task { await model.load() } }) { profile in
            if let reportingService {
                ReportProfileView(profile: profile, service: reportingService) {
                    onReportSubmitted(profile.id)
                }
            }
        }
        .privacySensitive()
    }
}
