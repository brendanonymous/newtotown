import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

private func response() -> [String: Any] {
    [
        "categories": (0..<5).map {
            [
                "id": "category_\($0)", "title": "Category \($0)",
                "options": [["id": "option_\($0)", "title": "Option \($0)"]],
            ]
        }, "profile_option_ids": ["option_0"], "filter_option_ids": [],
    ]
}
private func service(_ fixture: MessagingHTTPFixture) -> SupabaseInterestsService {
    SupabaseInterestsService(
        client: fixture.client, accountID: fixture.owner, configuration: fixture.configuration,
        session: fixture.session)
}
@Test func interestAdapterPinsOwnerAndEncodesEmptyFilterReplacement() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    try fixture.respond(response())
    let result = try await service(fixture).save([], for: .filters)
    #expect(result.isValid)
    let request = try #require(fixture.functionRequests.last)
    #expect(request.url?.path == "/functions/v1/interests")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(body.keys) == ["action", "selection_kind", "option_ids"])
    #expect(body["selection_kind"] as? String == "filters")
    #expect(body["option_ids"] as? [String] == [])
}
@Test func interestAdapterRejectsLateResponseAfterAccountSwitch() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(response(), hold: true)
    var started = fixture.started.stream.makeAsyncIterator()
    let request = Task { try await service(fixture).load() }
    await started.next()
    _ = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: InterestsError.signedOut) { try await request.value }
}
@Test func interestAdapterMapsServerValidationAndRejectsMalformedCatalog() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["error": "invalid"], status: 400)
    await #expect(throws: InterestsError.invalidSelection) {
        try await service(fixture).save(["unknown"], for: .profile)
    }
    try fixture.respond(["categories": [], "profile_option_ids": [], "filter_option_ids": []])
    await #expect(throws: InterestsError.connection) { try await service(fixture).load() }
}
