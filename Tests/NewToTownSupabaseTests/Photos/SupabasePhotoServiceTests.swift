import Foundation
import NewToTownCore
import Testing

@testable import NewToTownSupabase

private let photoJPEG = Data([0xff, 0xd8, 0xff, 0x01, 0xff, 0xd9])

private func photoFixture() async throws -> MessagingHTTPFixture {
    let fixture = try MessagingHTTPFixture()
    _ = try await fixture.signIn()
    fixture.respondRaw(Data("{\"photo_review_required\":false}".utf8), path: "/rest/v1/pilot_features")
    let names = ["profile.jpg", "profile-2.jpg", "profile-3.jpg", "selfie.jpg"]
    fixture.respondRaw(
        try JSONSerialization.data(withJSONObject: names.map { ["name": $0] }),
        path: "/storage/v1/object/list/private-photos", method: "POST")
    for (index, name) in names.enumerated() {
        let path = "/storage/v1/object/private-photos/\(fixture.owner.uuidString.lowercased())/\(name)"
        fixture.respondRaw(Data([0xff, 0xd8, 0xff, UInt8(index + 1), 0xff, 0xd9]), path: path)
        fixture.respondRaw(
            Data(
                "{\"Id\":\"00000000-0000-0000-0000-000000000091\",\"Key\":\"private-photos/photo.jpg\"}".utf8),
            path: path, method: "POST")
    }
    fixture.respondRaw(Data("[]".utf8), path: "/storage/v1/object/private-photos", method: "DELETE")
    return fixture
}

@Test func galleryDownloadsAllThreeInOrderWithoutTheSelfie() async throws {
    let fixture = try await photoFixture()
    let photos = try await SupabasePhotoService(client: fixture.client, accountID: fixture.owner)
        .loadProfilePhotos()
    #expect(photos.map { $0[3] } == [1, 2, 3])
    let selfiePath = "/storage/v1/object/private-photos/\(fixture.owner.uuidString.lowercased())/selfie.jpg"
    #expect(fixture.requests(to: selfiePath).isEmpty)
}

@Test func savingTwoPhotosDeletesOnlyTheObsoleteThirdSlotAndKeepsSelfiePrivate() async throws {
    let fixture = try await photoFixture()
    try await SupabasePhotoService(client: fixture.client, accountID: fixture.owner).save(
        PrivatePhotos(profile: photoJPEG, additionalProfiles: [photoJPEG]))
    let request = try #require(fixture.requests(to: "/storage/v1/object/private-photos").last)
    let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: [String]])
    #expect(body["prefixes"] == ["\(fixture.owner.uuidString.lowercased())/profile-3.jpg"])
    let selfiePath = "/storage/v1/object/private-photos/\(fixture.owner.uuidString.lowercased())/selfie.jpg"
    #expect(fixture.requests(to: selfiePath).isEmpty)
}

@Test func failedGalleryUploadNeverDeletesExistingSlots() async throws {
    let fixture = try await photoFixture()
    let path = "/storage/v1/object/private-photos/\(fixture.owner.uuidString.lowercased())/profile.jpg"
    fixture.respondRaw(Data("{}".utf8), path: path, method: "POST", status: 503)
    await #expect(throws: (any Error).self) {
        try await SupabasePhotoService(client: fixture.client, accountID: fixture.owner).save(
            PrivatePhotos(profile: photoJPEG))
    }
    #expect(fixture.requests(to: "/storage/v1/object/private-photos").isEmpty)
}

@Test func anOldPhotoEditorCannotUploadIntoANewlySignedInAccount() async throws {
    let fixture = try await photoFixture()
    let original = SupabasePhotoService(client: fixture.client, accountID: fixture.owner)
    _ = try await fixture.signIn(fixture.peer)
    await #expect(throws: PhotoServiceError.accountChanged) {
        try await original.save(PrivatePhotos(profile: photoJPEG))
    }
    #expect(fixture.requests(to: "/storage/v1/object/list/private-photos").isEmpty)
}
