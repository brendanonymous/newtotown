import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

@Test func reportsTransportHasNoCallerOrReviewFieldsAndPreservesRetryID() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    let id = UUID()
    try fixture.respond(["id": id.uuidString])
    let service = SupabaseProfileReportingService(
        client: fixture.client, accountID: fixture.owner, configuration: fixture.configuration,
        session: fixture.session)
    let report = ProfileReport(targetID: fixture.peer, reason: .nonPlatonic, details: nil)
    #expect(try await service.submit(report) == id)
    let request = try #require(fixture.functionRequests.last)
    #expect(request.url?.path == "/functions/v1/reports")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(body.keys) == ["target_id", "client_report_id", "reason", "details"])
    #expect(body["reason"] as? String == "non_platonic")
    #expect(body["client_report_id"] as? String == report.retryID.uuidString)
    #expect(body["details"] is NSNull)
}

@Test func reportsRejectAccountSwitchAndSelfReport() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    let service = SupabaseProfileReportingService(
        client: fixture.client, accountID: fixture.owner, configuration: fixture.configuration,
        session: fixture.session)
    await #expect(throws: ProfileReportingError.invalidReport) {
        try await service.submit(ProfileReport(targetID: fixture.owner, reason: .spam, details: nil))
    }
    _ = try await fixture.signIn(fixture.peer)
    await #expect(throws: ProfileReportingError.signedOut) {
        try await service.submit(ProfileReport(targetID: fixture.peer, reason: .spam, details: nil))
    }
    #expect(fixture.functionRequests.isEmpty)
}
