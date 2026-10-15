import Foundation
import Observation

@MainActor @Observable
public final class DiscoveryModel {
    public private(set) var feed: DiscoveryFeed?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let service: any DiscoveryService
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []

    public init(service: any DiscoveryService) { self.service = service }

    public func load() async {
        // A returning tab may refresh before its cancelled request has unwound.
        // Wait for the current operation instead of silently dropping the refresh.
        while isBusy && !Task.isCancelled {
            await withCheckedContinuation { refreshWaiters.append($0) }
        }
        guard !Task.isCancelled else { return }
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
        guard !isBusy, !Task.isCancelled else { return }
        isBusy = true
        errorMessage = nil
        defer {
            isBusy = false
            let waiters = refreshWaiters
            refreshWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        do {
            let updated = try await action()
            feed = Task.isCancelled ? nil : updated
        } catch {
            // Discard cached people on uncertain authorization/visibility changes.
            // Decisions are idempotent; refresh safely restores the server's result.
            feed = nil
            if !Task.isCancelled {
                errorMessage = "We couldn’t update discovery. Refresh to check your connections and try again."
            }
        }
    }
}
