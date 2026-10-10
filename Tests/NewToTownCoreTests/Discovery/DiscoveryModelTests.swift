import Foundation
import Testing
@testable import NewToTownCore

@MainActor private final class TestDiscoveryService: DiscoveryService {
    enum Failure: Error { case unavailable }
    var feed = DiscoveryFeed(state: .hidden, visible: false)
    var fails = false
    var visibilityCalls = 0
    var decisions: [UUID] = []
    func load() async throws -> DiscoveryFeed {
        if fails { throw Failure.unavailable }
        return feed
    }
    func setVisible(_ visible: Bool) async throws -> DiscoveryFeed {
        visibilityCalls += 1
        if fails { throw Failure.unavailable }
        feed = DiscoveryFeed(state: visible ? .ready : .hidden, visible: visible)
        return feed
    }
    func decide(on profileID: UUID, choice: ConnectionChoice) async throws -> DiscoveryFeed {
        decisions.append(profileID)
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

private let localFriend = DiscoveryProfile(id: UUID(), firstName: "Alex", jobTitle: "Designer",
    goal: "Find a hiking buddy.", city: "Scottsdale", photoURL: URL(string: "https://example.com/photo.jpg")!)

@Test @MainActor func discoveryNeedsVisibilityAgreementAndAllowsHidingWithoutIt() async {
    let service = TestDiscoveryService()
    let model = DiscoveryModel(service: service)
    await model.load()
    await model.setVisible(true)
    #expect(service.visibilityCalls == 0)
    model.acceptsVisibility = true
    await model.setVisible(true)
    #expect(model.feed?.visible == true)
    #expect(!model.acceptsVisibility)
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
