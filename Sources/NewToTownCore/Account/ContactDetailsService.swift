import Foundation

public enum ContactDetailKind: String, Identifiable, Sendable {
    case email, phone
    public var id: String { rawValue }
}

/// Normalized destination for adding a missing sign-in method to the current account.
public struct ContactDestination: Equatable, Sendable {
    public let kind: ContactDetailKind
    public let value: String
    public init?(kind: ContactDetailKind, input: String) {
        self.kind = kind
        switch kind {
        case .email:
            let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard text.count <= 254,
                text.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
            else { return nil }
            value = text
        case .phone:
            guard let number = PhoneNumber(rawValue: input) else { return nil }
            value = number.rawValue
        }
    }

    public func matches(_ info: PersonalInfo) -> Bool {
        switch kind {
        case .email: info.email?.lowercased() == value
        case .phone:
            if let phone = info.phone {
                (PhoneNumber(rawValue: phone) ?? PhoneNumber(rawValue: "+" + phone))?.rawValue == value
            } else {
                false
            }
        }
    }
}

public enum ContactDetailsError: Error, Equatable, Sendable {
    case signedOut, alreadyProvided, contactInUse, invalidCode, rateLimited, connection
}

public protocol ContactDetailsService: Sendable {
    /// Only adds missing contacts. Auth sends a verification email or SMS code; no account is created.
    func requestVerification(for destination: ContactDestination) async throws
    func resendVerification(for destination: ContactDestination) async throws
    /// Checks Auth after a browser verification; never adopts a session from a callback URL.
    func confirmedEmail() async throws -> PersonalInfo
    /// Returns fresh, confirmed details for the original authenticated owner.
    func verify(_ destination: ContactDestination, code: String) async throws -> PersonalInfo
}
