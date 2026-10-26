import Foundation

public struct PrivatePhotos: Equatable, Sendable {
    public var profile: Data?
    public var selfie: Data?
    public var additionalProfiles: [Data]
    public static let maximumProfilePhotos = 3
    public var profilePhotos: [Data] { [profile].compactMap { $0 } + additionalProfiles }

    public init(profile: Data? = nil, selfie: Data? = nil, additionalProfiles: [Data] = []) {
        self.profile = profile
        self.selfie = selfie
        self.additionalProfiles = additionalProfiles
    }

    public static let maximumFileSize = 3 * 1024 * 1024
    public var isComplete: Bool { profile != nil && selfie != nil }

    public func meets(_ requirements: PhotoRequirements) -> Bool {
        profile != nil && (!requirements.reviewRequired || selfie != nil)
    }

    public func validate(requirements: PhotoRequirements) throws {
        guard profilePhotos.count <= Self.maximumProfilePhotos else {
            throw PhotoValidationError.tooManyPhotos
        }
        guard meets(requirements) else { throw PhotoValidationError.missingPhoto }
        for data in profilePhotos + (requirements.reviewRequired ? [selfie].compactMap { $0 } : []) {
            guard data.count <= Self.maximumFileSize else { throw PhotoValidationError.tooLarge }
            guard data.starts(with: [0xff, 0xd8, 0xff]), data.suffix(2) == Data([0xff, 0xd9]) else {
                throw PhotoValidationError.invalidImage
            }
        }
    }
}

public enum PhotoValidationError: Error, LocalizedError {
    case missingPhoto, tooLarge, invalidImage, tooManyPhotos

    public var errorDescription: String? {
        switch self {
        case .tooManyPhotos: "You can add up to three profile photos."
        case .missingPhoto: "Add the required photos first."
        case .tooLarge: "Each photo must be smaller than 3 MB. Choose a smaller photo and try again."
        case .invalidImage: "We couldn’t read that photo. Choose it again or retake it."
        }
    }
}

public enum PhotoServiceError: Error, Sendable { case accountChanged }

public protocol PhotoService: Sendable {
    func requirements() async throws -> PhotoRequirements
    /// Ordered public-facing photos for the owner’s card. Never includes the private selfie.
    func loadProfilePhotos() async throws -> [Data]
    func load() async throws -> PrivatePhotos
    /// Rechecks server requirements; storage enforces the account’s recorded consent.
    /// Uploads are individually retryable, not atomic; review-off saves omit selfies.
    func save(_ photos: PrivatePhotos) async throws
    func remove() async throws
}
