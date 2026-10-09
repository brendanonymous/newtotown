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

    public func validate() throws {
        guard let profile, let selfie else { throw PhotoValidationError.missingPhoto }
        for data in [profile, selfie] {
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
        case .missingPhoto: "Choose a profile photo and take a selfie first."
        case .tooLarge: "Each photo must be smaller than 3 MB. Choose a smaller photo and try again."
        case .invalidImage: "We couldn’t read that photo. Choose it again or retake it."
        }
    }
}

public protocol PhotoService: Sendable {
    func load() async throws -> PrivatePhotos
    /// Persists consent before uploading. Uploads are individually retryable, not atomic.
    func save(_ photos: PrivatePhotos) async throws
    func remove() async throws
}
