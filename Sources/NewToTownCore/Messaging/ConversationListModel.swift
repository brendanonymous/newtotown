import Foundation
import Observation

@MainActor @Observable
public final class ConversationListModel {
    public private(set) var conversations: [Conversation] = []
    public private(set) var nextCursor: MessageCursor?
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    public private(set) var errorMessage: String?
    private let service: any MessagingService
    private var generation = 0

    public init(service: any MessagingService) { self.service = service }

    public func load(older: Bool = false) async {
        guard !isLoading, !Task.isCancelled, !older || nextCursor != nil else { return }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer { if current == generation { isLoading = false } }
        do {
            let page = try await service.conversations(before: older ? nextCursor : nil)
            guard current == generation else { return }
            guard !Task.isCancelled else {
                if !hasLoaded { errorMessage = "Loading was interrupted. Pull down to try again." }
                return
            }
            // Activity can move a conversation between pages; keep each ID once.
            var unique = Dictionary(
                (older ? conversations : []).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            for conversation in page.conversations { unique[conversation.id] = conversation }
            conversations = unique.values.sorted {
                let first = MessageText.date($0.lastActivityAt) ?? .distantPast
                let second = MessageText.date($1.lastActivityAt) ?? .distantPast
                return first == second ? $0.id.uuidString > $1.id.uuidString : first > second
            }
            nextCursor = page.nextCursor
            hasLoaded = true
        } catch {
            guard current == generation else { return }
            if Task.isCancelled {
                if !hasLoaded { errorMessage = "Loading was interrupted. Pull down to try again." }
            } else {
                conversations = []
                nextCursor = nil
                hasLoaded = false
                errorMessage =
                    error as? MessagingError == .signedOut
                    ? "Sign in again to see your conversations."
                    : "We couldn’t load messages. Check your connection and try again."
            }
        }
    }

    /// Invalidates in-flight responses as the screen/account leaves the signed-in shell.
    public func reset() {
        generation += 1
        conversations = []
        nextCursor = nil
        isLoading = false
        hasLoaded = false
        errorMessage = nil
    }
}
