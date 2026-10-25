import Foundation
import Testing

@testable import NewToTownCore

private let categories = (0..<5).map { category in
    InterestCategory(
        id: "category_\(category)", title: "Category \(category)",
        options: (0..<4).map {
            InterestOption(id: "option_\(category)_\($0)", title: "Option \($0)")
        })
}
@MainActor private final class InterestsFixture: InterestsService {
    var value = InterestsSnapshot(
        categories: categories, profileOptionIDs: [], filterOptionIDs: ["option_1_0"])
    var fail = false
    var hold = false
    var continuation: CheckedContinuation<InterestsSnapshot, Never>?
    let started = AsyncStream<Void>.makeStream()
    var saves = 0
    func load() async throws -> InterestsSnapshot {
        started.continuation.yield(())
        if hold { return await withCheckedContinuation { continuation = $0 } }
        if fail { throw InterestsError.connection }
        return value
    }
    func save(_ optionIDs: [String], for kind: InterestSelectionKind) throws -> InterestsSnapshot {
        saves += 1
        if fail { throw InterestsError.connection }
        value = InterestsSnapshot(
            categories: categories,
            profileOptionIDs: kind == .profile ? optionIDs : value.profileOptionIDs,
            filterOptionIDs: kind == .filters ? optionIDs : value.filterOptionIDs)
        return value
    }
}

@Test @MainActor func interestsLimitAllowsRemovalAtThreeAndRejectsUnknownOptions() async {
    let service = InterestsFixture()
    let model = InterestsModel(service: service, kind: .profile)
    await model.load()
    for id in ["option_0_0", "option_0_1", "option_0_2", "option_0_3", "unknown"] { model.toggle(id) }
    #expect(model.selected.count == 3)
    #expect(!model.canToggle("option_0_3"))
    #expect(model.canToggle("option_0_1"))
    model.toggle("option_0_1")
    model.toggle("option_0_3")
    #expect(model.selected == ["option_0_0", "option_0_2", "option_0_3"])
    #expect(model.canSave)
}
@Test @MainActor func profileAndFilterSavesStaySeparateAndCanBeCleared() async {
    let service = InterestsFixture()
    let profile = InterestsModel(service: service, kind: .profile)
    await profile.load()
    profile.toggle("option_0_0")
    #expect(await profile.save())
    #expect(service.value.filterOptionIDs == ["option_1_0"])
    #expect(!profile.canSave)
    let filters = InterestsModel(service: service, kind: .filters)
    await filters.load()
    filters.toggle("option_1_0")
    #expect(await filters.save())
    #expect(service.value.filterOptionIDs.isEmpty)
    #expect(service.value.profileOptionIDs == ["option_0_0"])
}
@Test @MainActor func failedInterestSavePreservesDraftForRetry() async {
    let service = InterestsFixture()
    let model = InterestsModel(service: service, kind: .profile)
    await model.load()
    model.toggle("option_0_1")
    service.fail = true
    #expect(!(await model.save()))
    #expect(model.selected == ["option_0_1"] && model.canSave && model.errorMessage != nil)
    service.fail = false
    #expect(await model.save())
    #expect(model.snapshot?.profileInterests.first?.title == "Option 1")
}
@Test @MainActor func leavingInterestEditorDiscardsLateAccountResponse() async {
    let service = InterestsFixture()
    service.hold = true
    let model = InterestsModel(service: service, kind: .profile)
    var started = service.started.stream.makeAsyncIterator()
    let request = Task { await model.load() }
    await started.next()
    model.reset()
    service.continuation?.resume(returning: service.value)
    await request.value
    #expect(model.snapshot == nil && model.selected.isEmpty && !model.isBusy)
}
@Test func interestSnapshotsRejectDuplicatesUnknownOptionsAndOverfullCategories() {
    #expect(InterestsSnapshot(categories: categories, profileOptionIDs: [], filterOptionIDs: []).isValid)
    for choices in [["unknown"], ["option_0_0", "option_0_0"], (0..<4).map { "option_0_\($0)" }] {
        #expect(
            !InterestsSnapshot(categories: categories, profileOptionIDs: choices, filterOptionIDs: []).isValid
        )
    }
    #expect(
        !InterestsSnapshot(
            categories: [categories[0], categories[0]] + Array(categories.dropFirst(2)), profileOptionIDs: [],
            filterOptionIDs: []
        ).isValid)
}
@Test func publicProfilesDecodeInterestLabelsAndRemainCompatibleWithOlderResponses() throws {
    var card: [String: Any] = [
        "id": UUID().uuidString, "first_name": "Alex", "job_title": "Designer", "goal": "Coffee",
        "city": "Scottsdale", "photo_url": "https://photo.example.test/profile.jpg",
    ]
    let legacy = try JSONDecoder().decode(
        DiscoveryProfile.self, from: JSONSerialization.data(withJSONObject: card))
    #expect(legacy.interests.isEmpty)
    card["interests"] = [["id": "coffee", "category_id": "food_drinks", "title": "Coffee"]]
    let current = try JSONDecoder().decode(
        DiscoveryProfile.self, from: JSONSerialization.data(withJSONObject: card))
    #expect(
        current.interests.first == ProfileInterest(id: "coffee", categoryID: "food_drinks", title: "Coffee"))
}
