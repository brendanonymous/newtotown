import Foundation

/// Private account contact details; never part of a discovery profile.
public struct PersonalInfo: Equatable, Sendable {
    public let email: String?
    public let phone: String?

    public init(email: String?, phone: String?) {
        self.email = Self.nonempty(email)
        self.phone = Self.nonempty(phone)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

public protocol PersonalInfoService: Sendable {
    /// Reads only the authenticated account; no caller-selected user ID.
    func load() async throws -> PersonalInfo
}
