import Foundation
import Testing

@testable import NewToTownCore

@MainActor private final class TestDiscoveryService: DiscoveryService {
    enum Failure: Error { case unavailable }
    var feed = DiscoveryFeed(state: .hidden, visible: false)
    var fails = false
    var visibilityCalls = 0
    var onVisibility: (@MainActor () async throws -> DiscoveryFeed)?
    var onLoad: (@MainActor () async throws -> DiscoveryFeed)?
    var onDecision: (@MainActor () async throws -> DiscoveryFeed)?
    var decisions: [UUID] = []
    func load() async throws -> DiscoveryFeed {
        if let onLoad { return try await onLoad() }
        if fails { throw Failure.unavailable }
        return feed
    }
    func setVisible(_ visible: Bool) async throws -> DiscoveryFeed {
        visibilityCalls += 1
        if let onVisibility { return try await onVisibility() }
        if fails { throw Failure.unavailable }
        feed = DiscoveryFeed(state: visible ? .ready : .hidden, visible: visible)
        return feed
    }
    func decide(on profileID: UUID, choice: ConnectionChoice) async throws -> DiscoveryFeed {
        decisions.append(profileID)
        if let onDecision { return try await onDecision() }
        if fails { throw Failure.unavailable }
        feed = DiscoveryFeed(state: .ready, visible: true, matches: feed.candidates)
        return feed
    }
    func block(_ profileID: UUID) async throws -> DiscoveryFeed {
        if fails { throw Failure.unavailable }
        feed = DiscoveryFeed(state: .ready, visible: true)
        return feed
    }
}

@Test @MainActor func decisionFeedbackWaitsForSuccessAndRejectsDuplicateTaps() async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    var response: CheckedContinuation<DiscoveryFeed, any Error>?
    service.onDecision = { try await withCheckedThrowingContinuation { response = $0 } }
    let decision = Task { await model.decide(.connect, on: localFriend.id) }
    while response == nil { await Task.yield() }
    #expect(model.pendingDecision == .connect && model.isBusy)
    #expect(model.feed?.candidates.first?.id == localFriend.id)
    await model.decide(.pass, on: localFriend.id)
    #expect(service.decisions == [localFriend.id])
    #expect(model.pendingDecision == .connect)
    response?.resume(returning: DiscoveryFeed(state: .ready, visible: true))
    await decision.value
    #expect(model.feed?.candidates.isEmpty == true)
    #expect(model.pendingDecision == nil && !model.isBusy)
}

@Test @MainActor func outgoingCardCannotDecideOnItsReplacement() async {
    let service = TestDiscoveryService()
    let next = DiscoveryProfile(
        id: UUID(), firstName: "Sam", jobTitle: "Teacher", goal: "Go hiking.",
        city: "Scottsdale", photoURL: localFriend.photoURL)
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [next])
    let model = DiscoveryModel(service: service)
    await model.load()
    await model.decide(.pass, on: localFriend.id)
    #expect(service.decisions.isEmpty)
    #expect(model.pendingDecision == nil)
    #expect(model.feed?.candidates.first?.id == next.id)
}

@Test(arguments: [false, true]) @MainActor
func failedOrCancelledDecisionClearsFeedback(cancelled: Bool) async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    service.onDecision = {
        if cancelled { withUnsafeCurrentTask { $0?.cancel() } }
        throw TestDiscoveryService.Failure.unavailable
    }
    await Task { await model.decide(.pass) }.value
    #expect(model.pendingDecision == nil && !model.isBusy)
    #expect(model.feed == nil && model.errorMessage != nil)
}

private let localFriend = DiscoveryProfile(
    id: UUID(), firstName: "Alex", jobTitle: "Designer",
    goal: "Find a hiking buddy.", city: "Scottsdale", photoURL: URL(string: "https://example.com/photo.jpg")!)

@Test @MainActor func discoveryJoinAndHideAreChoicesWithoutRepeatedAgreement() async {
    let service = TestDiscoveryService()
    let model = DiscoveryModel(service: service)
    await model.load()
    await model.setVisible(true)
    #expect(service.visibilityCalls == 1)
    #expect(model.feed?.visible == true)
    await model.setVisible(false)
    #expect(model.feed?.state == .hidden)
    #expect(service.visibilityCalls == 2)
}

@Test @MainActor func aDecisionUsesCurrentCardAndServerMatches() async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    await model.decide(.connect)
    #expect(service.decisions == [localFriend.id])
    #expect(model.feed?.candidates.isEmpty == true)
    #expect(model.feed?.matches == [localFriend])
}

@Test @MainActor func uncertainDecisionClearsCachedPeopleAndRefreshRestoresServerState() async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    service.fails = true
    await model.decide(.pass)
    #expect(model.feed == nil)
    #expect(!model.isBusy)
    #expect(model.errorMessage != nil)
    service.fails = false
    service.feed = DiscoveryFeed(state: .hidden, visible: false)
    await model.load()
    #expect(model.feed?.state == .hidden)
    #expect(model.errorMessage == nil)
}

@Test @MainActor func ineligibleFeedCannotSendDecisionAndBlockRefreshesConnections() async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .restricted, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    await model.decide(.connect)
    #expect(service.decisions.isEmpty)
    service.feed = DiscoveryFeed(state: .ready, visible: true, matches: [localFriend])
    await model.load()
    await model.block(localFriend.id)
    #expect(model.feed?.matches.isEmpty == true)
}

@Test @MainActor func returningToDiscoveryWaitsForCancelledLoadAndRefreshes() async {
    let service = TestDiscoveryService()
    let model = DiscoveryModel(service: service)
    let firstStarted = AsyncStream<Void>.makeStream()
    let secondStarted = AsyncStream<Void>.makeStream()
    var firstEvents = firstStarted.stream.makeAsyncIterator()
    var secondEvents = secondStarted.stream.makeAsyncIterator()
    var firstResponse: CheckedContinuation<DiscoveryFeed, any Error>?
    var loads = 0
    service.onLoad = {
        loads += 1
        if loads == 1 {
            return try await withCheckedThrowingContinuation { response in
                firstResponse = response
                firstStarted.continuation.yield(())
            }
        }
        return DiscoveryFeed(state: .ready, visible: true)
    }
    let cancelled = Task { await model.load() }
    await firstEvents.next()
    cancelled.cancel()
    let refreshed = Task {
        secondStarted.continuation.yield(())
        await model.load()
    }
    // The second task has reached its first suspension (or incorrectly returned).
    await secondEvents.next()
    firstResponse?.resume(throwing: CancellationError())
    await cancelled.value
    await refreshed.value
    #expect(loads == 2)
    #expect(model.feed?.state == .ready)
    #expect(model.errorMessage == nil)
    #expect(!model.isBusy)
    firstStarted.continuation.finish()
    secondStarted.continuation.finish()
}

@Test(arguments: [false, true]) @MainActor
func cancelledDiscoveryRefreshKeepsLoadedFeedAndCanRefreshAgain(throwsCancellation: Bool) async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    let previous = model.feed
    let started = AsyncStream<Void>.makeStream()
    var events = started.stream.makeAsyncIterator()
    var response: CheckedContinuation<DiscoveryFeed, any Error>?
    service.onLoad = {
        try await withCheckedThrowingContinuation {
            response = $0
            started.continuation.yield(())
        }
    }
    let refresh = Task { await model.load() }
    await events.next()
    refresh.cancel()
    if throwsCancellation {
        response?.resume(throwing: CancellationError())
    } else {
        response?.resume(returning: DiscoveryFeed(state: .hidden, visible: false))
    }
    await refresh.value
    #expect(model.feed == previous)
    #expect(model.errorMessage == nil)
    #expect(!model.isBusy)

    service.onLoad = nil
    service.feed = DiscoveryFeed(state: .ready, visible: true, matches: [localFriend])
    await model.load()
    #expect(model.feed?.matches == [localFriend])
    started.continuation.finish()
}

@Test @MainActor func cancelledInitialDiscoveryLoadOffersRetryInsteadOfBlankScreen() async {
    let service = TestDiscoveryService()
    let model = DiscoveryModel(service: service)
    service.onLoad = {
        withUnsafeCurrentTask { $0?.cancel() }
        throw CancellationError()
    }
    let load = Task { await model.load() }
    await load.value
    #expect(model.feed == nil)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
    service.onLoad = nil
    await model.load()
    #expect(model.feed?.state == .hidden)
    #expect(model.errorMessage == nil)
}

@Test @MainActor func cancelledVisibilityChangeClearsFeedAndOffersRecovery() async {
    let service = TestDiscoveryService()
    service.feed = DiscoveryFeed(state: .ready, visible: true, candidates: [localFriend])
    let model = DiscoveryModel(service: service)
    await model.load()
    service.onVisibility = {
        withUnsafeCurrentTask { $0?.cancel() }
        throw CancellationError()
    }
    let hide = Task { await model.setVisible(false) }
    await hide.value
    #expect(model.feed == nil)
    #expect(model.errorMessage != nil)
    #expect(!model.isBusy)
}

@Test @MainActor func confirmedReportPrunesDiscoveryAndConnectionsDespiteLateRead() async {
    let service = TestDiscoveryService()
    let other = DiscoveryProfile(
        id: UUID(), firstName: "Sam", jobTitle: "Teacher", goal: "Go hiking.",
        city: "Scottsdale", photoURL: localFriend.photoURL)
    service.feed = DiscoveryFeed(
        state: .ready, visible: true, candidates: [localFriend, other], matches: [localFriend, other])
    let model = DiscoveryModel(service: service)
    await model.load()
    var response: CheckedContinuation<DiscoveryFeed, Never>?
    service.onLoad = { await withCheckedContinuation { response = $0 } }
    let refresh = Task { await model.load() }
    while response == nil { await Task.yield() }
    model.excludeProfiles([localFriend.id])
    #expect(model.feed?.candidates.map(\.id) == [other.id])
    #expect(model.feed?.matches.map(\.id) == [other.id])
    response?.resume(returning: service.feed)
    await refresh.value
    #expect(model.feed?.candidates.map(\.id) == [other.id])
    #expect(model.feed?.matches.map(\.id) == [other.id])
    await model.decide(.connect)
    #expect(service.decisions == [other.id])
}
