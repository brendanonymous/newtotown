import Foundation

public enum ReportReason: String, CaseIterable, Sendable {
    case unwantedContact = "unwanted_contact"
    case inappropriateContent = "inappropriate_content"
    case nonPlatonic = "non_platonic"
    case spam, other

    public var title: String {
        switch self {
        case .unwantedContact: "Unwanted contact"
        case .inappropriateContent: "Inappropriate content"
        case .nonPlatonic: "Not using the app platonically"
        case .spam: "Spam"
        case .other: "Something else"
        }
    }
}

public struct ProfileReport: Equatable, Sendable {
    public static let maximumDetailsLength = 1000
    public let targetID: UUID
    public let retryID: UUID
    public let reason: ReportReason
    public let details: String?

    public init(targetID: UUID, retryID: UUID = UUID(), reason: ReportReason, details: String?) {
        self.targetID = targetID
        self.retryID = retryID
        self.reason = reason
        self.details = details
    }

    public var isValid: Bool {
        guard let details else { return true }
        return details.unicodeScalars.count <= Self.maximumDetailsLength && !details.contains("\0")
    }
}

public enum ProfileReportingError: Error, Equatable, Sendable {
    case signedOut, unavailable, invalidReport, retryConflict, connection
}

/// The implementation is bound to the signed-in reporter; the command has no caller identity.
public protocol ProfileReportingService: Sendable {
    /// A receipt confirms that the report and pair-specific contact prevention committed together.
    func submit(_ report: ProfileReport) async throws -> UUID
}
