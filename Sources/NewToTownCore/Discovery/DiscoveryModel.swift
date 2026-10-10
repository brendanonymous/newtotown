import Foundation
import Observation

@MainActor @Observable
public final class DiscoveryModel {
    public private(set) var feed: DiscoveryFeed?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let service: any DiscoveryService

    public init(service: any DiscoveryService) { self.service = service }

    public func load() async {
        await perform { try await self.service.load() }
    }

    public func setVisible(_ visible: Bool) async {
        await perform { try await self.service.setVisible(visible) }
    }

    public func decide(_ choice: ConnectionChoice) async {
        guard let profile = feed?.candidates.first, feed?.state == .ready else { return }
        await perform { try await self.service.decide(on: profile.id, choice: choice) }
    }

    public func block(_ profileID: UUID) async {
        await perform { try await self.service.block(profileID) }
    }

    private func perform(_ action: () async throws -> DiscoveryFeed) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            feed = try await action()
        } catch {
            // Discard cached people on uncertain authorization/visibility changes.
            // Decisions are idempotent; refresh safely restores the server's result.
            feed = nil
            errorMessage = "We couldn’t update discovery. Refresh to check your connections and try again."
        }
    }
}
