import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

private func contacts(_ fixture: MessagingHTTPFixture) -> SupabaseContactDetailsService {
    SupabaseContactDetailsService(
        client: fixture.client, accountID: fixture.owner,
        configuration: fixture.configuration, session: fixture.session)
}
private func destination(_ kind: ContactDetailKind) -> ContactDestination {
    ContactDestination(kind: kind, input: kind == .email ? "alex@example.com" : "+14805550123")!
}

@Test(arguments: [ContactDetailKind.email, .phone])
func addingContactUsesOwnerBearerAndNeverConfirmsAdministratively(kind: ContactDetailKind) async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    try fixture.respond(["id": fixture.owner.uuidString], path: "/auth/v1/user")
    try await contacts(fixture).requestVerification(for: destination(kind))
    let request = try #require(fixture.requests(to: "/auth/v1/user").last)
    #expect(request.httpMethod == "PUT")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(body == [kind.rawValue: destination(kind).value])
}

@Test(arguments: [ContactDetailKind.email, .phone])
func contactVerificationRequiresConfirmedOwnerAndKeepsExistingSession(kind: ContactDetailKind) async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    var user: [String: Any] = ["id": fixture.owner.uuidString, kind.rawValue: destination(kind).value]
    user[kind == .email ? "email_confirmed_at" : "phone_confirmed_at"] = "2026-10-25T00:00:00Z"
    try fixture.respond(user, path: "/auth/v1/user")
    try fixture.respond(user, path: "/auth/v1/verify")
    let result = try await contacts(fixture).verify(destination(kind), code: "123456")
    #expect(destination(kind).matches(result))
    let request = try #require(fixture.requests(to: "/auth/v1/verify").last)
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(
        body == [
            kind.rawValue: destination(kind).value, "token": "123456",
            "type": kind == .email ? "email_change" : "phone_change",
        ])
    #expect(fixture.client.auth.currentSession?.accessToken == token)
}

@Test func existingContactCannotBeOverwrittenAndUnconfirmedContactIsRejected() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    let user: [String: Any] = ["id": fixture.owner.uuidString, "email": "alex@example.com"]
    try fixture.respond(user, path: "/auth/v1/user")
    await #expect(throws: ContactDetailsError.alreadyProvided) {
        try await contacts(fixture).requestVerification(for: destination(.email))
    }
    #expect(!fixture.requests(to: "/auth/v1/user").contains { $0.httpMethod == "PUT" })
    try fixture.respond(user, path: "/auth/v1/verify")
    await #expect(throws: ContactDetailsError.invalidCode) {
        try await contacts(fixture).verify(destination(.email), code: "123456")
    }
}

@Test func contactRequestDiscardsResponseAfterAccountSwitch() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["id": fixture.owner.uuidString], hold: true, path: "/auth/v1/resend")
    var started = fixture.started.stream.makeAsyncIterator()
    let pending = Task { try await contacts(fixture).resendVerification(for: destination(.phone)) }
    await started.next()
    _ = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: ContactDetailsError.signedOut) { try await pending.value }
    #expect(fixture.client.auth.currentSession?.user.id == fixture.peer)
}

@Test func contactAdapterMapsDuplicateAndRateLimitErrors() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["error_code": "phone_exists"], status: 422, path: "/auth/v1/resend")
    await #expect(throws: ContactDetailsError.contactInUse) {
        try await contacts(fixture).resendVerification(for: destination(.phone))
    }
    try fixture.respond([:], status: 429, path: "/auth/v1/resend")
    await #expect(throws: ContactDetailsError.rateLimited) {
        try await contacts(fixture).resendVerification(for: destination(.phone))
    }
}

@Test func lateContactVerificationCannotReplaceAnotherAccountsSession() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(["access_token": "must-never-be-installed"], hold: true, path: "/auth/v1/verify")
    var started = fixture.started.stream.makeAsyncIterator()
    let pending = Task { try await contacts(fixture).verify(destination(.email), code: "12345678") }
    await started.next()
    let nextToken = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: ContactDetailsError.signedOut) { try await pending.value }
    #expect(fixture.client.auth.currentSession?.accessToken == nextToken)
    #expect(fixture.client.auth.currentSession?.user.id == fixture.peer)
}

@Test func emailRequestAndResendCarryExplicitRedirectButSMSDoesNot() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    let redirect = EmailVerificationCallback.redirectURL(scheme: "com.newtotown.ios.test")
    let service = SupabaseContactDetailsService(
        client: fixture.client, accountID: fixture.owner, configuration: fixture.configuration,
        session: fixture.session, emailRedirectURL: redirect)
    try fixture.respond(["id": fixture.owner.uuidString], path: "/auth/v1/user")
    try await service.requestVerification(for: destination(.email))
    try fixture.respond([:], path: "/auth/v1/resend")
    try await service.resendVerification(for: destination(.email))
    for path in ["/auth/v1/user", "/auth/v1/resend"] {
        let request = try #require(fixture.requests(to: path).last)
        let url = try #require(request.url)
        #expect(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems == [
                URLQueryItem(name: "redirect_to", value: redirect.absoluteString)
            ])
    }
    try await service.resendVerification(for: destination(.phone))
    #expect(fixture.requests(to: "/auth/v1/resend").last?.url?.query == nil)
}

@Test func browserVerificationReadsConfirmedOriginalOwnerWithoutAcceptingURLSessions() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    try fixture.respond(
        [
            "id": fixture.owner.uuidString, "email": "alex@example.com",
            "email_confirmed_at": "2026-10-25T00:00:00Z",
        ], path: "/auth/v1/user")
    #expect(try await contacts(fixture).confirmedEmail().email == "alex@example.com")
    #expect(fixture.client.auth.currentSession?.accessToken == token)
    #expect(fixture.requests(to: "/auth/v1/verify").isEmpty)
    try fixture.respond(["id": fixture.owner.uuidString, "email": "alex@example.com"], path: "/auth/v1/user")
    await #expect(throws: ContactDetailsError.invalidCode) { try await contacts(fixture).confirmedEmail() }
    try fixture.respond(
        [
            "id": fixture.peer.uuidString, "email": "peer@example.com",
            "email_confirmed_at": "2026-10-25T00:00:00Z",
        ], path: "/auth/v1/user")
    await #expect(throws: ContactDetailsError.signedOut) { try await contacts(fixture).confirmedEmail() }
}

@Test func browserConfirmationDiscardsALateResponseAfterSwitchingAccounts() async throws {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    try fixture.respond(
        [
            "id": fixture.owner.uuidString, "email": "alex@example.com",
            "email_confirmed_at": "2026-10-25T00:00:00Z",
        ], hold: true, path: "/auth/v1/user")
    var started = fixture.started.stream.makeAsyncIterator()
    let pending = Task { try await contacts(fixture).confirmedEmail() }
    await started.next()
    // The fixture intercepts GET /user for both clients. Switch using a fresh
    // payload so the SDK can finish signing in, then release the original read.
    try fixture.respond(
        [
            "id": fixture.peer.uuidString, "aud": "authenticated",
            "created_at": "2026-10-17T00:00:00Z", "updated_at": "2026-10-17T00:00:00Z",
        ], path: "/auth/v1/user")
    let nextToken = try await fixture.signIn(fixture.peer)
    fixture.release()
    await #expect(throws: ContactDetailsError.signedOut) { try await pending.value }
    #expect(fixture.client.auth.currentSession?.accessToken == nextToken)
}
