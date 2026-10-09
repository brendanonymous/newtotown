import Foundation
import NewToTownCore
import Supabase

public final class SupabasePhotoService: PhotoService {
    private let client: SupabaseClient
    private let bucket = "private-photos"

    init(client: SupabaseClient) { self.client = client }

    public func requirements() async throws -> PhotoRequirements {
        let flags: PhotoFlags = try await client.from("pilot_features")
            .select("photo_review_required").eq("id", value: true).single().execute().value
        return PhotoRequirements(reviewRequired: flags.photoReviewRequired)
    }

    public func load() async throws -> PrivatePhotos {
        let folder = try await ownerFolder()
        let storage = client.storage.from(bucket)
        let names = Set(try await storage.list(path: folder).map(\.name))
        let profile = names.contains("profile.jpg") ? try await storage.download(path: "\(folder)/profile.jpg") : nil
        let selfie = names.contains("selfie.jpg") ? try await storage.download(path: "\(folder)/selfie.jpg") : nil
        return PrivatePhotos(profile: profile, selfie: selfie)
    }

    public func save(_ photos: PrivatePhotos) async throws {
        let requirements = try await requirements()
        try photos.validate(requirements: requirements)
        let folder = try await ownerFolder()
        // Record the first acceptance of this version using the database timestamp.
        try await client.from("photo_consents").upsert(
            PhotoConsent(userID: folder, version: "pilot-v1"),
            onConflict: "user_id", ignoreDuplicates: true
        ).execute()
        let storage = client.storage.from(bucket)
        let options = FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: true)
        if let profile = photos.profile {
            try await storage.upload("\(folder)/profile.jpg", data: profile, options: options)
        }
        if requirements.reviewRequired, let selfie = photos.selfie {
            try await storage.upload("\(folder)/selfie.jpg", data: selfie, options: options)
        }
    }

    public func remove() async throws {
        let folder = try await ownerFolder()
        try await client.storage.from(bucket).remove(paths: ["\(folder)/profile.jpg", "\(folder)/selfie.jpg"])
    }

    private func ownerFolder() async throws -> String {
        try await client.auth.session.user.id.uuidString.lowercased()
    }
}

private struct PhotoConsent: Encodable {
    let userID: String
    let version: String
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case version
    }
}

private struct PhotoFlags: Decodable {
    let photoReviewRequired: Bool
    enum CodingKeys: String, CodingKey {
        case photoReviewRequired = "photo_review_required"
    }
}
