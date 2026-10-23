import NewToTownCore
import SwiftUI

struct ConversationListView: View {
    let accountID: UUID
    let service: any MessagingService
    let isSelected: Bool
    @State private var model: ConversationListModel
    @Environment(\.scenePhase) private var scenePhase

    init(accountID: UUID, service: any MessagingService, isSelected: Bool) {
        self.accountID = accountID
        self.service = service
        self.isSelected = isSelected
        _model = State(initialValue: ConversationListModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Messages").font(.system(.largeTitle, design: .serif))
                if model.hasLoaded && model.conversations.isEmpty {
                    Text("Start with hello.").font(.title2)
                    Text("Open a mutual connection in Connections to start a conversation.")
                        .foregroundStyle(BrandTheme.secondaryInk)
                }
                ForEach(model.conversations) { conversation in
                    NavigationLink {
                        ChatView(
                            accountID: accountID, target: .conversation(conversation.id), service: service)
                    } label: {
                        HStack(spacing: 16) {
                            MessagePhoto(url: conversation.participant.photoURL)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(conversation.participant.firstName).font(.headline)
                                Text(conversation.lastMessage?.body ?? "Say hello.")
                                    .font(.callout).foregroundStyle(BrandTheme.secondaryInk).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("messages.conversation.\(conversation.id.uuidString)")
                    Divider()
                }
                if model.nextCursor != nil {
                    Button("Load more conversations") { Task { await model.load(older: true) } }
                        .disabled(model.isLoading)
                }
                if model.isLoading { ProgressView("Loading messages…") }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await model.load() }
        .task(id: isSelected) { if isSelected { await model.load() } }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active { Task { await model.load() } }
        }
        .onDisappear { model.reset() }
        .privacySensitive()
    }
}
