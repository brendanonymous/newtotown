import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

@Test func messagingWireContractPreservesCursorAndSendsNoCallerIdentity() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    let cursor = MessageCursor(time: fixture.time, id: fixture.thread)
    try fixture.respond([
        "conversations": [fixture.conversationJSON],
        "next_cursor": ["time": fixture.time, "id": fixture.thread.uuidString],
    ])
    let page = try await fixture.service().conversations(before: cursor)
    #expect(page.nextCursor == cursor)
    #expect(page.conversations.first?.participant.id == fixture.peer)
    let request = try #require(fixture.functionRequests.last)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
    #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
    let body = try #require(request.httpBody)
    let command = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(Set(command.keys) == Set(["action", "cursor"]))
    #expect((command["cursor"] as? [String: String])?["time"] == fixture.time)
}

@Test func sendAndBlockUseTheApprovedEndpointsAndStableRetryKey() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    let service = fixture.service()
    let retry = UUID()
    let body = "  Coffee on Saturday?  "
    try fixture.respond(fixture.messageJSON(retry: retry, body: body))
    let sent = try await service.send(in: fixture.thread, retryID: retry, body: body)
    #expect(sent.clientMessageID == retry && sent.body == body)
    let request = try #require(fixture.functionRequests.last)
    let data = try #require(request.httpBody)
    let command = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(command.keys) == Set(["action", "conversation_id", "client_message_id", "body"]))
    #expect(request.url?.path == "/functions/v1/messaging")
    try fixture.respond(["state": "ready"])
    try await service.block(fixture.peer)
    #expect(fixture.functionRequests.last?.url?.path == "/functions/v1/discovery")
}

@Test(arguments: [400, 401, 404, 409, 503])
func messagingMapsStatusCodesWithoutExposingUpstreamBodies(status: Int) async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["error": "private upstream details"], status: status)
    let expected: MessagingError = [
        400: .invalidMessage, 401: .signedOut, 404: .unavailable, 409: .retryConflict, 503: .connection,
    ][status]!
    await #expect(throws: expected) { try await fixture.service().conversations(before: nil) }
}

@Test func accountBoundServiceCannotSendUsingAnotherAccountsSession() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn(fixture.peer)
    await #expect(throws: MessagingError.signedOut) { try await fixture.service().conversations(before: nil) }
    #expect(fixture.functionRequests.isEmpty)
}

@Test func responseIsRejectedWhenAccountChangesDuringRequest() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["conversations": [fixture.conversationJSON], "next_cursor": NSNull()], hold: true)
    var started = fixture.started.stream.makeAsyncIterator()
    let request = Task { try await fixture.service().conversations(before: nil) }
    await started.next()
    _ = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: MessagingError.signedOut) { try await request.value }
}

@Test func malformedHistoryAndMismatchedSendResponsesFailClosed() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    let retry = UUID()
    var message = fixture.messageJSON(retry: retry, body: "Hello")
    message["conversation_id"] = fixture.peer.uuidString
    try fixture.respond([
        "conversation": fixture.conversationJSON, "messages": [message], "next_cursor": NSNull(),
    ])
    await #expect(throws: MessagingError.connection) {
        try await fixture.service().history(in: fixture.thread, before: nil)
    }
    try fixture.respond(message)
    await #expect(throws: MessagingError.connection) {
        try await fixture.service().send(in: fixture.thread, retryID: retry, body: "Hello")
    }
}
