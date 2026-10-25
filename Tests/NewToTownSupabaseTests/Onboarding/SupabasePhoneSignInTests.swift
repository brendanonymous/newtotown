import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

@Test func phoneSignInUsesSupabaseSMSAndExistingEmailFallbackCannotCreateAccount() async throws {
    let fixture = try MessagingHTTPFixture()
    let service = SupabaseOnboardingService(client: fixture.client)
    try fixture.respond([:], path: "/auth/v1/otp")
    let phone = try #require(PhoneNumber(rawValue: "4805550142"))
    try await service.sendCode(to: .phone(phone))
    var request = try #require(fixture.requests(to: "/auth/v1/otp").last)
    var data = try #require(request.httpBody)
    var body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(body["phone"] as? String == "+14805550142")
    #expect(body["channel"] as? String == "sms" && body["create_user"] as? Bool == true)
    #expect(body["email"] == nil)
    try await service.sendCode(to: .email("alex@example.test"))
    request = try #require(fixture.requests(to: "/auth/v1/otp").last)
    data = try #require(request.httpBody)
    body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(body["email"] as? String == "alex@example.test")
    #expect(body["create_user"] as? Bool == false && body["phone"] == nil)
}

@Test func phoneVerificationUsesSMSTypeAndRestoresSameSupabaseSession() async throws {
    let fixture = try MessagingHTTPFixture()
    let token = try await fixture.signIn()
    let phone = try #require(PhoneNumber(rawValue: "4805550142"))
    try fixture.respond(
        [
            "access_token": token, "refresh_token": "verified-test-refresh", "token_type": "bearer",
            "expires_in": 3600,
            "expires_at": Date().timeIntervalSince1970 + 3600,
            "user": [
                "id": fixture.owner.uuidString, "aud": "authenticated", "phone": phone.rawValue,
                "created_at": "2026-10-17T00:00:00Z", "updated_at": "2026-10-17T00:00:00Z",
            ],
        ], path: "/auth/v1/verify")
    let service = SupabaseOnboardingService(client: fixture.client)
    #expect(try await service.verifyCode("123456", identifier: .phone(phone)) == fixture.owner)
    #expect(try await service.currentUserID() == fixture.owner)
    let request = try #require(fixture.requests(to: "/auth/v1/verify").last)
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(body["phone"] as? String == phone.rawValue && body["type"] as? String == "sms")
    #expect(body["token"] as? String == "123456" && body["email"] == nil)
}
