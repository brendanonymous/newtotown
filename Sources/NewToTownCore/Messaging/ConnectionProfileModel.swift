import Foundation
import Observation

/// Fetch through the existing conversation-authorized endpoint for fresh profile/photo access.
/// Keep only the public profile projection, not the returned message history.
@MainActor @Observable
public final class ConnectionProfileModel {
    public private(set) var profile: DiscoveryProfile?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let conversationID: UUID
    private let service: any MessagingService
    private var generation = 0

    public init(conversationID: UUID, service: any MessagingService) {
        self.conversationID = conversationID
        self.service = service
    }

    public func load() async {
        guard !isLoading, !Task.isCancelled else { return }
        let current = generation
        isLoading = true
        errorMessage = nil
        defer { if current == generation { isLoading = false } }
        do {
            let page = try await service.history(in: conversationID, before: nil)
            guard current == generation, !Task.isCancelled else { return }
            guard page.conversation.id == conversationID else { throw MessagingError.unavailable }
            profile = page.conversation.participant
        } catch {
            guard current == generation else { return }
            profile = nil
            errorMessage =
                error as? MessagingError == .unavailable
                ? "This profile is no longer available."
                : "We couldn’t load this profile. Please try again."
        }
    }

    public func reset() {
        generation += 1
        profile = nil
        isLoading = false
        errorMessage = nil
    }
}
