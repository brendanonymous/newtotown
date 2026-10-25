import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

private func preferencesService(_ fixture: MessagingHTTPFixture) -> SupabaseDiscoveryPreferencesService {
    SupabaseDiscoveryPreferencesService(
        client: fixture.client, accountID: fixture.owner,
        configuration: fixture.configuration, session: fixture.session)
}

@Test func preferencesWireContractUsesOwnerTokenAndExplicitNullMaximum() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    try fixture.respond(["minimum_age": 25, "maximum_age": NSNull()])
    let saved = try await preferencesService(fixture).save(AgePreferences(minimumAge: 25))
    #expect(saved == AgePreferences(minimumAge: 25))
    let request = try #require(fixture.functionRequests.last)
    #expect(request.url?.path == "/functions/v1/discovery")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
    let data = try #require(request.httpBody)
    let command = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(command.keys) == ["action", "minimum_age", "maximum_age"])
    #expect(command["maximum_age"] is NSNull)
    #expect(command["action"] as? String == "save_preferences")
}

@Test func preferencesRejectAnotherAccountAndMalformedServerRanges() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn(fixture.peer)
    await #expect(throws: DiscoveryPreferencesError.signedOut) {
        try await preferencesService(fixture).load()
    }
    #expect(fixture.functionRequests.isEmpty)
    _ = try await fixture.signIn()
    try fixture.respond(["minimum_age": 50, "maximum_age": 20])
    await #expect(throws: DiscoveryPreferencesError.connection) {
        try await preferencesService(fixture).load()
    }
    await #expect(throws: DiscoveryPreferencesError.invalidRange) {
        try await preferencesService(fixture).save(AgePreferences(minimumAge: 17))
    }
}

@Test func preferencesDiscardResponseAfterAccountSwitch() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["minimum_age": 18, "maximum_age": NSNull()], hold: true)
    var started = fixture.started.stream.makeAsyncIterator()
    let request = Task { try await preferencesService(fixture).load() }
    await started.next()
    _ = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: DiscoveryPreferencesError.signedOut) { try await request.value }
}
