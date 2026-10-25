import Foundation
import NewToTownCore
import Supabase

/// Freeze the owner's bearer token for Auth writes as well as reads. Using the shared
/// SDK's update/verify methods here could replace another account's session after a switch.
/// The existing SDK session remains in charge of persistence and normal token refresh.
public final class SupabaseContactDetailsService: ContactDetailsService {
    private let client: SupabaseClient
    private let accountID: UUID
    private let configuration: SupabaseConfiguration
    private let session: URLSession

    init(
        client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
        session: URLSession = .shared
    ) {
        self.client = client
        self.accountID = accountID
        self.configuration = configuration
        self.session = session
    }

    public func requestVerification(for destination: ContactDestination) async throws {
        let token = try await credentials()
        let user = try await user(token: token)
        let info = user.info
        guard destination.kind == .email ? info.email == nil : info.phone == nil else {
            throw ContactDetailsError.alreadyProvided
        }
        // No confirmation flags or administrative credentials; Auth must send and verify the code.
        let data = try await request(
            "user", method: "PUT", body: [destination.kind.rawValue: destination.value], token: token)
        guard try JSONDecoder().decode(ContactUser.self, from: data).id == accountID else {
            throw ContactDetailsError.signedOut
        }
    }

    public func resendVerification(for destination: ContactDestination) async throws {
        let token = try await credentials()
        _ = try await request(
            "resend", method: "POST",
            body: [destination.kind.rawValue: destination.value, "type": verificationType(destination)],
            token: token)
    }

    public func verify(_ destination: ContactDestination, code: String) async throws -> PersonalInfo {
        guard (6...10).contains(code.count), code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw ContactDetailsError.invalidCode
        }
        let token = try await credentials()
        _ = try await request(
            "verify", method: "POST",
            body: [
                destination.kind.rawValue: destination.value, "token": code,
                "type": verificationType(destination),
            ], token: token, fallback: .invalidCode)
        // A /verify response may contain a session. Do not replace the app's shared session.
        // Read the original owner through the captured token and require server confirmation.
        let confirmed = try await user(token: token)
        let timestamp = destination.kind == .email ? confirmed.emailConfirmedAt : confirmed.phoneConfirmedAt
        guard destination.matches(confirmed.info), timestamp?.isEmpty == false else {
            throw ContactDetailsError.invalidCode
        }
        return confirmed.info
    }

    private func verificationType(_ destination: ContactDestination) -> String {
        destination.kind == .email ? "email_change" : "phone_change"
    }

    private func credentials() async throws -> String {
        do {
            let value = try await client.auth.session
            guard value.user.id == accountID else { throw ContactDetailsError.signedOut }
            return value.accessToken
        } catch AuthError.sessionMissing { throw ContactDetailsError.signedOut }
    }

    private func user(token: String) async throws -> ContactUser {
        let data = try await request("user", method: "GET", body: nil, token: token)
        let value = try JSONDecoder().decode(ContactUser.self, from: data)
        guard value.id == accountID else { throw ContactDetailsError.signedOut }
        return value
    }

    private func request(
        _ path: String, method: String, body: [String: String]?, token: String,
        fallback: ContactDetailsError = .connection
    ) async throws -> Data {
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == accountID else { throw ContactDetailsError.signedOut }
        var request = URLRequest(
            url: configuration.projectURL.appendingPathComponent("auth/v1").appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try body.map { try JSONEncoder().encode($0) }
        let (data, response) = try await session.data(for: request)
        guard client.auth.currentSession?.user.id == accountID else { throw ContactDetailsError.signedOut }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw ContactDetailsError.connection }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw ContactDetailsError.signedOut }
            if http.statusCode == 429 { throw ContactDetailsError.rateLimited }
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = error?["error_code"] as? String ?? error?["code"] as? String ?? ""
            if ["email_exists", "phone_exists", "user_already_exists"].contains(code) {
                throw ContactDetailsError.contactInUse
            }
            if code.contains("rate_limit") { throw ContactDetailsError.rateLimited }
            if [400, 422].contains(http.statusCode) { throw fallback }
            throw ContactDetailsError.connection
        }
        return data
    }
}

private struct ContactUser: Decodable {
    let id: UUID
    let email: String?
    let phone: String?
    let emailConfirmedAt: String?
    let phoneConfirmedAt: String?
    var info: PersonalInfo { PersonalInfo(email: email, phone: phone) }
    enum CodingKeys: String, CodingKey {
        case id, email, phone
        case emailConfirmedAt = "email_confirmed_at"
        case phoneConfirmedAt = "phone_confirmed_at"
    }
}
