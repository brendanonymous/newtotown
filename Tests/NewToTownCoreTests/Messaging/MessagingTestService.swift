import Foundation
import NewToTownCore

let messagingOwner = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
let messagingPeer = DiscoveryProfile(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
    firstName: "Alex", jobTitle: "Designer", goal: "Find a hiking buddy.", city: "Scottsdale",
    photoURL: URL(string: "https://example.com/profile.jpg")!)
let messagingTime = "2026-10-17T23:00:00.123456+00:00"
let messagingThread = Conversation(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
    participant: messagingPeer, createdAt: messagingTime, lastActivityAt: messagingTime, lastMessage: nil)

@MainActor final class MessagingTestService: MessagingService {
    var listPages: [ConversationPage] = []
    var historyPages: [MessagePage] = []
    var sendCalls: [(UUID, String)] = []
    var historyCursors: [MessageCursor?] = []
    var onList: (() async throws -> ConversationPage)?
    var onHistory: (() async throws -> MessagePage)?
    var onSend: ((UUID, String) async throws -> ChatMessage)?
    var blockFails = false
    var blocks: [UUID] = []
    func conversations(before cursor: MessageCursor?) async throws -> ConversationPage {
        if let onList { return try await onList() }
        return listPages.isEmpty
            ? ConversationPage(conversations: [messagingThread], nextCursor: nil) : listPages.removeFirst()
    }
    func open(with peerID: UUID) async throws -> Conversation { messagingThread }
    func history(in conversationID: UUID, before cursor: MessageCursor?) async throws -> MessagePage {
        historyCursors.append(cursor)
        if let onHistory { return try await onHistory() }
        return historyPages.isEmpty
            ? MessagePage(conversation: messagingThread, messages: [], nextCursor: nil)
            : historyPages.removeFirst()
    }
    func send(in conversationID: UUID, retryID: UUID, body: String) async throws -> ChatMessage {
        sendCalls.append((retryID, body))
        if let onSend { return try await onSend(retryID, body) }
        return ChatMessage(
            id: retryID, conversationID: conversationID, senderID: messagingOwner,
            clientMessageID: retryID, body: body, createdAt: messagingTime)
    }
    func block(_ peerID: UUID) async throws {
        blocks.append(peerID)
        if blockFails { throw MessagingError.connection }
    }
}
