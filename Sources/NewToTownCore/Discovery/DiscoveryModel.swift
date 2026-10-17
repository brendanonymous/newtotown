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
        await perform(preserveOnCancellation: true) { try await self.service.load() }
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

    private func perform(
        preserveOnCancellation: Bool = false,
        _ action: () async throws -> DiscoveryFeed
    ) async {
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
            if Task.isCancelled {
                finishCancellation(preserveFeed: preserveOnCancellation)
            } else {
                feed = updated
            }
        } catch {
            if Task.isCancelled {
                finishCancellation(preserveFeed: preserveOnCancellation)
                return
            }
            // Discard cached people on uncertain authorization/visibility changes.
            // Decisions are idempotent; refresh safely restores the server's result.
            feed = nil
            errorMessage = "We couldn’t update discovery. Pull down to refresh or try again."
        }
    }

    private func finishCancellation(preserveFeed: Bool) {
        // A cancelled read has no new server state to publish. Keep the current
        // feed; uncertain mutations still discard it until a fresh read succeeds.
        if !preserveFeed { feed = nil }
        if feed == nil {
            errorMessage = "Loading was interrupted. Pull down to refresh or try again."
        }
    }
}
