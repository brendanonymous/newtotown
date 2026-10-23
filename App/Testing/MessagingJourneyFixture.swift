#if DEBUG
    import Foundation
    import NewToTownCore
    import SwiftUI

    /// Offline dependencies for simulator UI tests only. Compiled out of release builds.
    struct MessagingJourneyFixture: View {
        @State private var account = OnboardingModel(service: JourneyAccountService())
        private let first = JourneyMessagingService(
            owner: JourneyIDs.first, name: "Alex", marker: "Account A conversation",
            startsEmpty: ProcessInfo.processInfo.arguments.contains("--ui-test-empty-chat"))
        private let second = JourneyMessagingService(
            owner: JourneyIDs.second, name: "Taylor", marker: "Account B conversation")

        var body: some View {
            AppEntryView(
                model: account, personalInfoService: nil, photoService: nil,
                discoveryService: JourneyDiscoveryService(
                    messages: account.accountID == JourneyIDs.second ? second : first),
                makeMessagingService: { id in id == JourneyIDs.second ? second : first })
        }
    }

    private enum JourneyIDs {
        static let first = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        static let second = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        static let peer = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        static let thread = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        static let time = "2026-10-17T23:00:00.123456Z"
    }

    private actor JourneyAccountService: OnboardingService {
        private var owner: UUID? = JourneyIDs.first
        func currentUserID() -> UUID? { owner }
        func sendCode(to email: String) {}
        func verifyCode(_ code: String, email: String) -> UUID {
            owner = JourneyIDs.second
            return JourneyIDs.second
        }
        func hasAcceptedAgreement(for userID: UUID) -> Bool { true }
        func acceptAgreement(for userID: UUID) {}
        func save(_ profile: Profile) {}
        func profile(for userID: UUID) throws -> Profile? {
            var draft = ProfileDraft()
            draft.firstName = "Fixture member"
            draft.jobTitle = "Designer"
            draft.goal = "Find a hiking buddy."
            draft.dateOfBirth = "1990-01-01"
            draft.platonicAgreement = true
            return try Profile(id: userID, draft: draft)
        }
        func signOut() { owner = nil }
        func deleteAccount() { owner = nil }
    }

    @MainActor private final class JourneyMessagingService: MessagingService {
        private let owner: UUID
        private let marker: String
        private let startsEmpty: Bool
        var hasStarted: Bool { !startsEmpty || !sent.isEmpty }
        private var sent: [ChatMessage] = []
        private var failedFirstSend = false
        private(set) var blocked = false
        let thread: Conversation

        init(owner: UUID, name: String, marker: String, startsEmpty: Bool = false) {
            self.owner = owner
            self.marker = marker
            self.startsEmpty = startsEmpty
            let peer = DiscoveryProfile(
                id: JourneyIDs.peer, firstName: name, jobTitle: "Designer",
                goal: "Find a hiking buddy.", city: "Scottsdale",
                photoURL: URL(fileURLWithPath: "/uitest-photo-placeholder"))
            thread = Conversation(
                id: JourneyIDs.thread, participant: peer, createdAt: JourneyIDs.time,
                lastActivityAt: JourneyIDs.time, lastMessage: nil)
        }
        private var greeting: ChatMessage {
            ChatMessage(
                id: JourneyIDs.peer, conversationID: thread.id, senderID: JourneyIDs.peer,
                clientMessageID: JourneyIDs.peer, body: marker, createdAt: JourneyIDs.time)
        }
        func conversations(before cursor: MessageCursor?) throws -> ConversationPage {
            let summary = Conversation(
                id: thread.id, participant: thread.participant, createdAt: thread.createdAt,
                lastActivityAt: thread.lastActivityAt, lastMessage: sent.last ?? greeting)
            return ConversationPage(conversations: blocked || !hasStarted ? [] : [summary], nextCursor: nil)
        }
        func open(with peerID: UUID) throws -> Conversation {
            guard !blocked else { throw MessagingError.unavailable }
            return thread
        }
        func history(in conversationID: UUID, before cursor: MessageCursor?) throws -> MessagePage {
            guard !blocked else { throw MessagingError.unavailable }
            return MessagePage(
                conversation: thread, messages: (startsEmpty ? [] : [greeting]) + sent, nextCursor: nil)
        }
        func send(in conversationID: UUID, retryID: UUID, body: String) throws -> ChatMessage {
            guard !blocked else { throw MessagingError.unavailable }
            if let previous = sent.first(where: { $0.clientMessageID == retryID }) { return previous }
            let message = ChatMessage(
                id: retryID, conversationID: thread.id, senderID: owner,
                clientMessageID: retryID, body: body, createdAt: JourneyIDs.time)
            sent.append(message)
            if !failedFirstSend {
                failedFirstSend = true
                throw MessagingError.connection
            }
            return message
        }
        func block(_ peerID: UUID) { blocked = true }
    }

    @MainActor private final class JourneyDiscoveryService: DiscoveryService {
        let messages: JourneyMessagingService
        init(messages: JourneyMessagingService) { self.messages = messages }
        func load() -> DiscoveryFeed {
            DiscoveryFeed(
                state: .ready, visible: true,
                matches: messages.blocked || messages.hasStarted ? [] : [messages.thread.participant])
        }
        func setVisible(_ visible: Bool) -> DiscoveryFeed { load() }
        func decide(on profileID: UUID, choice: ConnectionChoice) -> DiscoveryFeed { load() }
        func block(_ profileID: UUID) -> DiscoveryFeed {
            messages.block(profileID)
            return load()
        }
    }
#endif
