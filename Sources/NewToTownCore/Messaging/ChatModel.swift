import Foundation
import Observation

@MainActor @Observable
public final class ChatModel {
    public let accountID: UUID
    public private(set) var conversation: Conversation?
    public private(set) var messages: [ChatMessage] = []
    public private(set) var nextCursor: MessageCursor?
    public var draft = ""
    public private(set) var pending: PendingMessage?
    public private(set) var isLoading = false
    public private(set) var isSending = false
    public private(set) var isUnavailable = false
    public private(set) var isBlocking = false
    public private(set) var errorMessage: String?
    public private(set) var sendError: String?
    public private(set) var blockFailed = false

    public struct PendingMessage: Equatable, Sendable {
        public let id: UUID
        public let body: String
    }
    private let target: ConversationTarget
    private let messagingService: any MessagingService
    private var generation = 0
    private var blockedPeer: UUID?

    public init(accountID: UUID, target: ConversationTarget, messagingService: any MessagingService) {
        self.accountID = accountID
        self.target = target
        self.messagingService = messagingService
    }

    public var canSend: Bool {
        conversation != nil && !isLoading && !isSending && !isUnavailable && pending == nil
            && MessageText.isValid(draft)
    }

    public func load(older: Bool = false) async {
        guard !isLoading, !isSending, !isUnavailable, !Task.isCancelled, !older || nextCursor != nil else {
            return
        }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer { if current == generation { isLoading = false } }
        do {
            let threadID: UUID
            if let conversation {
                threadID = conversation.id
            } else {
                switch target {
                case .conversation(let id): threadID = id
                case .peer(let id): threadID = try await messagingService.open(with: id).id
                }
            }
            guard current == generation else { return }
            guard !Task.isCancelled else {
                interruptedLoad()
                return
            }
            let page = try await messagingService.history(in: threadID, before: older ? nextCursor : nil)
            guard current == generation else { return }
            guard !Task.isCancelled else {
                interruptedLoad()
                return
            }
            conversation = page.conversation
            messages = merge(older ? messages : [], with: page.messages)
            nextCursor = page.nextCursor
        } catch {
            guard current == generation else { return }
            if Task.isCancelled { interruptedLoad() } else { handleLoadFailure(error) }
        }
    }

    public func send() async {
        guard canSend else { return }
        pending = PendingMessage(id: UUID(), body: draft)
        await retrySend()
    }

    public func retrySend() async {
        guard let pending, let conversation, !isSending, !isLoading, !isUnavailable, !Task.isCancelled else {
            return
        }
        let current = generation
        isSending = true
        sendError = nil
        defer { if current == generation { isSending = false } }
        do {
            let sent = try await messagingService.send(in: conversation.id, retryID: pending.id, body: pending.body)
            guard current == generation else { return }
            guard !Task.isCancelled else {
                sendError = "Send was interrupted. Retry the same message safely."
                return
            }
            messages = merge(messages, with: [sent])
            // A refresh may already have recovered a send whose response was lost.
            self.pending = nil
            draft = ""
        } catch {
            guard current == generation else { return }
            if error as? MessagingError == .unavailable || error as? MessagingError == .signedOut {
                handleLoadFailure(error)
            } else if error as? MessagingError == .invalidMessage
                || error as? MessagingError == .retryConflict
            {
                self.pending = nil
                sendError = "This message wasn’t accepted. Check your draft and try again."
            } else {
                sendError = "We couldn’t confirm this send. Retry to avoid sending it twice."
            }
        }
    }

    public func block() async {
        guard !isBlocking, let peer = blockedPeer ?? conversation?.participant.id else { return }
        generation += 1
        let current = generation
        blockedPeer = peer
        clearContent()
        isUnavailable = true
        isBlocking = true
        blockFailed = false
        defer { if current == generation { isBlocking = false } }
        do {
            try await messagingService.block(peer)
            guard current == generation else { return }
            errorMessage = "You blocked this connection."
        } catch {
            guard current == generation else { return }
            blockFailed = true
            errorMessage = "We couldn’t confirm the block. Try again."
        }
    }

    public func reset() {
        generation += 1
        clearContent()
        isUnavailable = false
        isBlocking = false
        blockFailed = false
        blockedPeer = nil
        errorMessage = nil
    }

    private func clearContent() {
        conversation = nil
        messages = []
        nextCursor = nil
        draft = ""
        pending = nil
        sendError = nil
        isSending = false
        isLoading = false
    }
    private func interruptedLoad() {
        if conversation == nil { errorMessage = "Loading was interrupted. Pull down to try again." }
    }
    private func handleLoadFailure(_ error: Error) {
        conversation = nil
        messages = []
        nextCursor = nil
        if error as? MessagingError == .unavailable || error as? MessagingError == .signedOut {
            clearContent()
            isUnavailable = true
            errorMessage = "This conversation is unavailable. It may be hidden or no longer connected."
        } else {
            errorMessage = "We couldn’t load this conversation. Check your connection and try again."
        }
    }
    private func merge(_ existing: [ChatMessage], with incoming: [ChatMessage]) -> [ChatMessage] {
        var unique = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for message in incoming { unique[message.id] = message }
        return unique.values.sorted {
            let first = MessageText.date($0.createdAt) ?? .distantPast
            let second = MessageText.date($1.createdAt) ?? .distantPast
            return first == second ? $0.id.uuidString < $1.id.uuidString : first < second
        }
    }
}
