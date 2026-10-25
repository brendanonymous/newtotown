import NewToTownCore
import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel
    private let messagingService: any MessagingService
    private let reportingService: (any ProfileReportingService)?
    let reportedProfileIDs: Set<UUID>
    let onReportSubmitted: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reportTarget: DiscoveryProfile?
    @State private var showsProfile = false
    @State private var historyPosition: UUID?
    @State private var hasScrolledHistory = false
    @Environment(\.scenePhase) private var scenePhase

    init(
        accountID: UUID,
        target: ConversationTarget,
        messagingService: any MessagingService,
        reportingService: (any ProfileReportingService)?,
        reportedProfileIDs: Set<UUID>,
        onReportSubmitted: @escaping (UUID) -> Void
    ) {
        self.messagingService = messagingService
        self.reportingService = reportingService
        self.reportedProfileIDs = reportedProfileIDs
        self.onReportSubmitted = onReportSubmitted
        _model = State(
            initialValue: ChatModel(accountID: accountID, target: target, messagingService: messagingService))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let peer = model.conversation?.participant {
                Button {
                    showsProfile = true
                } label: {
                    HStack(spacing: 16) {
                        MessagePhoto(url: peer.photoURL)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.firstName).font(.title2).accessibilityIdentifier("chat.peer")
                            Label(peer.jobTitle, systemImage: "briefcase")
                                .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(.horizontal, 28).padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(peer.firstName)’s profile")
                .accessibilityIdentifier("chat.viewProfile")
                Divider()
            }
            history
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .safeAreaInset(edge: .bottom) { if model.conversation != nil && !model.isUnavailable { composer } }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            BrandNavigationLogo()
            if model.conversation != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    if reportingService != nil {
                        Button("Report", systemImage: "flag") {
                            reportTarget = model.conversation?.participant
                        }
                    }
                }
            }
        }
        .sheet(item: $reportTarget, onDismiss: { Task { await model.load() } }) { profile in
            if let reportingService {
                ReportProfileView(profile: profile, service: reportingService) {
                    model.reset()
                    onReportSubmitted(profile.id)
                    dismiss()
                }
            }
        }
        .navigationDestination(isPresented: $showsProfile) {
            if let conversation = model.conversation {
                ConnectionProfileView(conversationID: conversation.id, service: messagingService)
            }
        }
        .task {
            model.excludeProfiles(reportedProfileIDs)
            if !showsProfile && reportTarget == nil { await model.load() }
        }
        .onChange(of: reportedProfileIDs) { _, ids in
            let removesCurrent = model.conversation.map { ids.contains($0.participant.id) } ?? false
            model.excludeProfiles(ids)
            if removesCurrent {
                showsProfile = false
                dismiss()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !showsProfile && reportTarget == nil { Task { await model.load() } }
        }
        .onDisappear { if !showsProfile && reportTarget == nil { model.reset() } }
        .privacySensitive()
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if model.nextCursor != nil {
                        Button(
                            model.olderPageFailed ? "Try loading earlier messages" : "Load earlier messages"
                        ) {
                            Task {
                                let first = model.messages.first?.id
                                await model.load(older: true)
                                if let first { proxy.scrollTo(first, anchor: .top) }
                            }
                        }.disabled(model.isLoading || model.isSending)
                    }
                    if model.conversation != nil && model.messages.isEmpty && !model.isLoading {
                        Text("Say hello.").font(.system(.title2, design: .serif))
                        Text("Make a plan to meet up.").foregroundStyle(BrandTheme.secondaryInk)
                    }
                    ForEach(model.messages) { message in
                        MessageBubble(
                            text: message.body, timestamp: message.createdAt,
                            isOwn: message.senderID == model.accountID
                        )
                        .id(message.id)
                    }
                    if let pending = model.pending,
                        !model.messages.contains(where: {
                            $0.clientMessageID == pending.id && $0.senderID == model.accountID
                        })
                    {
                        MessageBubble(text: pending.body, timestamp: nil, isOwn: true)
                            .opacity(0.65)
                        Text(model.isSending ? "Sending…" : "Not confirmed")
                            .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if model.isLoading { ProgressView() }
                    if let error = model.errorMessage {
                        Text(error).font(.callout).foregroundStyle(
                            model.isUnavailable ? BrandTheme.secondaryInk : .red
                        )
                        .accessibilityIdentifier("chat.error")
                        if !model.isUnavailable && !model.olderPageFailed {
                            Button("Try again") { Task { await model.load() } }
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("chat.history")
            .defaultScrollAnchor(.bottom)
            .scrollPosition(id: $historyPosition)
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(DragGesture().onChanged { _ in hasScrolledHistory = true })
            .refreshable { await model.load() }
            .onChange(of: historyPosition) { _, id in
                if hasScrolledHistory, id != nil, id == model.messages.first?.id,
                    model.nextCursor != nil, !model.isLoading, !model.olderPageFailed
                {
                    Task { await model.load(older: true) }
                }
            }
            .onChange(of: model.messages.last?.id) { _, id in
                if let id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = model.sendError {
                Text(error).font(.callout).foregroundStyle(.red)
                if model.pending != nil {
                    Button("Retry send") { Task { await model.retrySend() } }
                        .accessibilityIdentifier("chat.retrySend").disabled(
                            model.isSending || model.isLoading)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5).textFieldStyle(BrandTextFieldStyle())
                    .onChange(of: model.draft) { model.limitDraft() }
                    .accessibilityIdentifier("chat.composer")
                    .disabled(model.pending != nil || model.isSending)

                Button {
                    Task { await model.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .accessibilityLabel("Send message").accessibilityIdentifier("chat.send")
                .disabled(!model.canSend)
                .opacity(model.canSend ? 1 : 0.4)
            }

            Text(
                model.draft.unicodeScalars.count == MessageText.maximumLength
                    ? "Character limit reached · \(MessageText.maximumLength)/\(MessageText.maximumLength)"
                    : "\(model.draft.unicodeScalars.count)/\(MessageText.maximumLength)"
            )
            .font(.caption)
            .foregroundStyle(BrandTheme.secondaryInk)
            .accessibilityIdentifier("chat.characterCount")
        }
        .padding(.horizontal, 28).padding(.vertical, 12)
        .background(BrandTheme.background)
    }
}

private struct MessageBubble: View {
    let text: String
    let timestamp: String?
    let isOwn: Bool
    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 5) {
            Text(text).textSelection(.enabled)
                .padding(14)
                .foregroundStyle(isOwn ? BrandTheme.background : BrandTheme.ink)
                .background(
                    isOwn ? BrandTheme.ink : BrandTheme.sage.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: BrandTheme.textCornerRadius))

            if let timestamp, let date = MessageText.date(timestamp) {
                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2).foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}
