import Foundation

/// Keep the original timestamp string: history cursors must preserve server microseconds.
public struct MessageCursor: Codable, Equatable, Sendable {
    public let time: String
    public let id: UUID
    public init(time: String, id: UUID) {
        self.time = time
        self.id = id
    }
}

public struct ChatMessage: Decodable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let senderID: UUID
    public let clientMessageID: UUID
    public let body: String
    public let createdAt: String

    public init(
        id: UUID, conversationID: UUID, senderID: UUID, clientMessageID: UUID, body: String, createdAt: String
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.clientMessageID = clientMessageID
        self.body = body
        self.createdAt = createdAt
    }
    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case clientMessageID = "client_message_id"
        case createdAt = "created_at"
    }
}

public struct Conversation: Decodable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let participant: DiscoveryProfile
    public let createdAt: String
    public let lastActivityAt: String
    public let lastMessage: ChatMessage?

    public init(
        id: UUID, participant: DiscoveryProfile, createdAt: String, lastActivityAt: String,
        lastMessage: ChatMessage?
    ) {
        self.id = id
        self.participant = participant
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.lastMessage = lastMessage
    }
    enum CodingKeys: String, CodingKey {
        case id, participant
        case createdAt = "created_at"
        case lastActivityAt = "last_activity_at"
        case lastMessage = "last_message"
    }
}

public struct ConversationPage: Decodable, Sendable {
    public let conversations: [Conversation]
    public let nextCursor: MessageCursor?
    public init(conversations: [Conversation], nextCursor: MessageCursor?) {
        self.conversations = conversations
        self.nextCursor = nextCursor
    }
    enum CodingKeys: String, CodingKey {
        case conversations
        case nextCursor = "next_cursor"
    }
}

public struct MessagePage: Decodable, Sendable {
    public let conversation: Conversation
    public let messages: [ChatMessage]
    public let nextCursor: MessageCursor?
    public init(conversation: Conversation, messages: [ChatMessage], nextCursor: MessageCursor?) {
        self.conversation = conversation
        self.messages = messages
        self.nextCursor = nextCursor
    }
    enum CodingKeys: String, CodingKey {
        case conversation, messages
        case nextCursor = "next_cursor"
    }
}

public enum ConversationTarget: Hashable, Sendable {
    case peer(UUID)
    case conversation(UUID)
}

public enum MessagingError: Error, Equatable, Sendable {
    case signedOut, unavailable, invalidMessage, retryConflict, connection
}

/// Implementations are bound to one account. No caller/sender identity is sent in a command.
public protocol MessagingService: Sendable {
    func conversations(before cursor: MessageCursor?) async throws -> ConversationPage
    func open(with peerID: UUID) async throws -> Conversation
    func history(in conversationID: UUID, before cursor: MessageCursor?) async throws -> MessagePage
    func send(in conversationID: UUID, retryID: UUID, body: String) async throws -> ChatMessage
    func block(_ peerID: UUID) async throws
}

public enum MessageText {
    public static let maximumLength = 500

    /// Keep one space between words and one newline between nonempty lines.
    public static func normalizedWhitespace(_ value: String) -> String {
        value.components(separatedBy: .newlines)
            .map { line in
                line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }.joined(separator: " ")
            }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Match message validation while keeping composed characters (such as emoji) intact.
    public static func limitedDraft(_ value: String) -> String {
        var scalarCount = 0
        return String(
            value.prefix { character in
                scalarCount += character.unicodeScalars.count
                return scalarCount <= maximumLength
            })
    }

    public static func isValid(_ value: String) -> Bool {
        let whitespace = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))
        return !value.trimmingCharacters(in: whitespace).isEmpty
            && !value.contains("\0") && value.unicodeScalars.count <= maximumLength
    }

    public static func date(_ timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }
}
