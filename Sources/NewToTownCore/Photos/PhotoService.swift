import Foundation

public struct PrivatePhotos: Equatable, Sendable {
    public var profile: Data?
    public var selfie: Data?

    public init(profile: Data? = nil, selfie: Data? = nil) {
        self.profile = profile
        self.selfie = selfie
    }

    public static let maximumFileSize = 3 * 1024 * 1024
    public var isComplete: Bool { profile != nil && selfie != nil }

    public func meets(_ requirements: PhotoRequirements) -> Bool {
        profile != nil && (!requirements.reviewRequired || selfie != nil)
    }

    public func validate(requirements: PhotoRequirements) throws {
        guard meets(requirements) else { throw PhotoValidationError.missingPhoto }
        for data in [profile, requirements.reviewRequired ? selfie : nil].compactMap({ $0 }) {
            guard data.count <= Self.maximumFileSize else { throw PhotoValidationError.tooLarge }
            guard data.starts(with: [0xff, 0xd8, 0xff]), data.suffix(2) == Data([0xff, 0xd9]) else {
                throw PhotoValidationError.invalidImage
            }
        }
    }
}

public enum PhotoValidationError: Error, LocalizedError {
    case missingPhoto, tooLarge, invalidImage

    public var errorDescription: String? {
        switch self {
        case .missingPhoto: "Add the required photos first."
        case .tooLarge: "Each photo must be smaller than 3 MB. Choose a smaller photo and try again."
        case .invalidImage: "We couldn’t read that photo. Choose it again or retake it."
        }
    }
}

public protocol PhotoService: Sendable {
    func requirements() async throws -> PhotoRequirements
    func load() async throws -> PrivatePhotos
    /// Rechecks server requirements; storage enforces the account’s recorded consent.
    /// Uploads are individually retryable, not atomic; review-off saves omit selfies.
    func save(_ photos: PrivatePhotos) async throws
    func remove() async throws
}
