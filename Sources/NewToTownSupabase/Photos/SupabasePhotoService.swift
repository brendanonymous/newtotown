import Foundation
import NewToTownCore
import Supabase

public final class SupabasePhotoService: PhotoService {
    private let client: SupabaseClient
    private let accountID: UUID
    private let bucket = "private-photos"
    private static let profileNames = ["profile.jpg", "profile-2.jpg", "profile-3.jpg"]
    private static let allNames = profileNames + ["selfie.jpg"]

    init(client: SupabaseClient, accountID: UUID) {
        self.client = client
        self.accountID = accountID
    }

    public func requirements() async throws -> PhotoRequirements {
        let flags: PhotoFlags = try await client.from("pilot_features")
            .select("photo_review_required").eq("id", value: true).single().execute().value
        return PhotoRequirements(reviewRequired: flags.photoReviewRequired)
    }

    public func loadProfilePhotos() async throws -> [Data] {
        let folder = try await ownerFolder()
        let names = try await storedNames(folder: folder)
        guard names.contains(Self.profileNames[0]) else { return [] }
        return try await downloadProfiles(folder: folder, names: names)
    }

    public func load() async throws -> PrivatePhotos {
        let folder = try await ownerFolder()
        let names = try await storedNames(folder: folder)
        let profiles = try await downloadProfiles(folder: folder, names: names)
        let selfie =
            names.contains("selfie.jpg")
            ? try await client.storage.from(bucket).download(path: "\(folder)/selfie.jpg") : nil
        try checkOwner(folder)
        return PrivatePhotos(
            profile: profiles.first, selfie: selfie, additionalProfiles: Array(profiles.dropFirst()))
    }

    public func save(_ photos: PrivatePhotos) async throws {
        let folder = try await ownerFolder()
        let requirements = try await requirements()
        try checkOwner(folder)
        try photos.validate(requirements: requirements)
        let storage = client.storage.from(bucket)
        let options = FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: true)
        // Complete all uploads before deleting obsolete slots. A failed save keeps
        // the draft available for retry; Storage writes are not an atomic batch.
        for (index, data) in photos.profilePhotos.enumerated() {
            try checkOwner(folder)
            try await storage.upload("\(folder)/\(Self.profileNames[index])", data: data, options: options)
            try checkOwner(folder)
        }
        if requirements.reviewRequired, let selfie = photos.selfie {
            try await storage.upload("\(folder)/selfie.jpg", data: selfie, options: options)
            try checkOwner(folder)
        }
        let names = try await storedNames(folder: folder)
        let obsolete = Self.profileNames.dropFirst(photos.profilePhotos.count).filter { names.contains($0) }
        if !obsolete.isEmpty {
            try checkOwner(folder)
            try await storage.remove(paths: obsolete.map { "\(folder)/\($0)" })
            try checkOwner(folder)
        }
    }

    public func remove() async throws {
        let folder = try await ownerFolder()
        try await client.storage.from(bucket).remove(paths: Self.allNames.map { "\(folder)/\($0)" })
        try checkOwner(folder)
    }

    private func storedNames(folder: String) async throws -> Set<String> {
        try checkOwner(folder)
        let objects = try await client.storage.from(bucket).list(path: folder)
        try checkOwner(folder)
        return Set(objects.map(\.name))
    }

    private func downloadProfiles(folder: String, names: Set<String>) async throws -> [Data] {
        let storage = client.storage.from(bucket)
        let available = Self.profileNames.filter { names.contains($0) }
        let photos = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, name) in available.enumerated() {
                group.addTask { (index, try await storage.download(path: "\(folder)/\(name)")) }
            }
            var results: [(Int, Data)] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        try checkOwner(folder)
        return photos
    }

    private func ownerFolder() async throws -> String {
        let session = try await client.auth.session
        guard session.user.id == accountID else { throw PhotoServiceError.accountChanged }
        return accountID.uuidString.lowercased()
    }

    private func checkOwner(_ folder: String) throws {
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id.uuidString.lowercased() == folder else {
            throw PhotoServiceError.accountChanged
        }
    }
}

private struct PhotoFlags: Decodable {
    let photoReviewRequired: Bool
    enum CodingKeys: String, CodingKey {
        case photoReviewRequired = "photo_review_required"
    }
}
