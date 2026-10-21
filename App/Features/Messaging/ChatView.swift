import NewToTownCore
import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel
    @State private var confirmsBlock = false
    @Environment(\.scenePhase) private var scenePhase

    init(accountID: UUID, target: ConversationTarget, service: any MessagingService) {
        _model = State(initialValue: ChatModel(accountID: accountID, target: target, service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let peer = model.conversation?.participant {
                HStack(spacing: 16) {
                    MessagePhoto(url: peer.photoURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(peer.firstName).font(.title2).accessibilityIdentifier("chat.peer")
                        Label(peer.jobTitle, systemImage: "briefcase")
                            .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                    }
                    Spacer()
                }.padding(.horizontal, 28).padding(.vertical, 16)
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
                    Button("Block", systemImage: "hand.raised") { confirmsBlock = true }
                }
            }
        }
        .confirmationDialog("Block this connection?", isPresented: $confirmsBlock, titleVisibility: .visible)
        {
            Button("Block connection", role: .destructive) { Task { await model.block() } }
        } message: {
            Text("You won’t see each other in discovery, connections, or messages.")
        }
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
        .onDisappear { model.reset() }
        .privacySensitive()
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if model.nextCursor != nil {
                        Button("Load earlier messages") {
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
                    if model.isLoading { ProgressView("Loading conversation…") }
                    if model.isBlocking { ProgressView("Blocking…") }
                    if let error = model.errorMessage {
                        Text(error).font(.callout).foregroundStyle(
                            model.isUnavailable ? BrandTheme.secondaryInk : .red
                        )
                        .accessibilityIdentifier("chat.error")
                        if model.blockFailed {
                            Button("Try blocking again") { Task { await model.block() } }
                        } else if !model.isUnavailable {
                            Button("Try again") { Task { await model.load() } }
                        }
                    }
                }
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await model.load() }
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
                    .lineLimit(1...5).textFieldStyle(.roundedBorder)
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
            if model.draft.unicodeScalars.count > MessageText.maximumLength {
                Text("Keep your message under \(MessageText.maximumLength) characters.").font(.caption).foregroundStyle(.red)
            }
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
                    in: RoundedRectangle(cornerRadius: 16))
            if let timestamp, let date = MessageText.date(timestamp) {
                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2).foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}
