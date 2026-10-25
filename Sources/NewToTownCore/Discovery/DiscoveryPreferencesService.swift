import Foundation

public struct AgePreferences: Codable, Equatable, Sendable {
    public let minimumAge: Int
    public let maximumAge: Int?

    public init(minimumAge: Int = 18, maximumAge: Int? = nil) {
        self.minimumAge = minimumAge
        self.maximumAge = maximumAge
    }

    public var isValid: Bool {
        minimumAge >= 18 && minimumAge <= Int(Int32.max)
            && (maximumAge.map { $0 >= minimumAge && $0 <= Int(Int32.max) } ?? true)
    }

    enum CodingKeys: String, CodingKey {
        case minimumAge = "minimum_age"
        case maximumAge = "maximum_age"
    }
}

public enum DiscoveryPreferencesError: Error, Equatable, Sendable {
    case signedOut, invalidRange, connection
}

/// Implementations belong to one signed-in account and persist preferences on the server.
public protocol DiscoveryPreferencesService: Sendable {
    func load() async throws -> AgePreferences
    func save(_ preferences: AgePreferences) async throws -> AgePreferences
}
