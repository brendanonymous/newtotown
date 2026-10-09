import Foundation
import Testing
@testable import NewToTownCore

@MainActor
private final class TestPhotoService: PhotoService {
    enum Failure: Error { case unavailable }
    var stored = PrivatePhotos()
    var policy = PhotoRequirements(reviewRequired: true)
    var failRequirements = false
    var failSave = false
    var failRemove = false
    var saves = 0
    func requirements() async throws -> PhotoRequirements {
        if failRequirements { throw Failure.unavailable }
        return policy
    }
    func load() async throws -> PrivatePhotos { stored }
    func save(_ photos: PrivatePhotos) async throws {
        saves += 1
        if failSave { throw Failure.unavailable }
        stored = photos
    }
    func remove() async throws {
        if failRemove { throw Failure.unavailable }
        stored = PrivatePhotos()
    }
}

private let jpeg = Data([0xff, 0xd8, 0xff, 0x01, 0xff, 0xd9])

@Test @MainActor func photosRequireBothImagesAndExplicitConsent() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.captureSelfie(jpeg)
    await model.save()
    #expect(service.saves == 0)
    model.hasConsent = true
    await model.save()
    #expect(model.isSaved)
    #expect(!model.hasConsent)
    #expect(service.stored.isComplete)
}

@Test @MainActor func photoValidationStopsMissingOversizedAndInvalidFiles() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.hasConsent = true
    await model.save()
    #expect(service.saves == 0)
    model.captureSelfie(Data([0, 1, 2]))
    model.hasConsent = true
    await model.save()
    #expect(service.saves == 0)
    model.captureSelfie(Data(repeating: 0, count: PrivatePhotos.maximumFileSize + 1))
    model.hasConsent = true
    await model.save()
    #expect(service.saves == 0)
    #expect(model.errorMessage != nil)
}

@Test @MainActor func failedPhotoSaveRetainsSelectionsForRetry() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.captureSelfie(jpeg)
    model.hasConsent = true
    service.failSave = true
    await model.save()
    #expect(!model.isSaved)
    #expect(model.photos.isComplete)
    #expect(model.hasConsent)
    #expect(!model.isBusy)
    service.failSave = false
    await model.save()
    #expect(model.isSaved)
}

@Test @MainActor func restoresPrivatePhotosAndReplacementRequiresConsentAgain() async {
    let service = TestPhotoService()
    service.stored = PrivatePhotos(profile: jpeg, selfie: jpeg)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    #expect(model.isSaved)
    model.hasConsent = true
    model.captureSelfie(jpeg)
    #expect(!model.isSaved)
    #expect(!model.hasConsent)
}

@Test @MainActor func removalFailureIsRetryableWithoutClaimingSuccess() async {
    let service = TestPhotoService()
    service.stored = PrivatePhotos(profile: jpeg, selfie: jpeg)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    service.failRemove = true
    await model.remove()
    #expect(model.photos.isComplete)
    #expect(!model.isSaved)
    #expect(model.errorMessage != nil)
    service.failRemove = false
    await model.remove()
    #expect(model.photos == PrivatePhotos())
    #expect(model.errorMessage == nil)
}

@Test @MainActor func pilotSavesProfileWithoutSelfieAndDoesNotSubmitOldSelfie() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.hasConsent = true
    await model.save()
    #expect(model.isSaved)
    #expect(service.stored.profile == jpeg)
    #expect(service.stored.selfie == nil)
    model.captureSelfie(jpeg)
    model.hasConsent = true
    await model.save()
    #expect(service.stored.selfie == nil)
}

@Test @MainActor func pilotRestoresProfileOnlyAsSaved() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    service.stored = PrivatePhotos(profile: jpeg)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    #expect(model.isSaved)
    #expect(model.requirements?.reviewRequired == false)
}

@Test @MainActor func enablingReviewWhileScreenIsOpenRequiresSelfieBeforeSaving() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.hasConsent = true
    service.policy = PhotoRequirements(reviewRequired: true)
    await model.save()
    #expect(service.saves == 0)
    #expect(model.requirements?.reviewRequired == true)
    #expect(!model.hasConsent)
    #expect(!model.isSaved)
    #expect(model.photos.profile == jpeg)
    model.captureSelfie(jpeg)
    model.hasConsent = true
    await model.save()
    #expect(model.isSaved)
}

@Test @MainActor func unknownRequirementsBlockLoadAndSaveWithoutLosingSelections() async {
    let service = TestPhotoService()
    service.failRequirements = true
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    #expect(!model.isLoaded)
    #expect(model.requirements == nil)
    service.failRequirements = false
    await model.load()
    model.selectProfile(jpeg)
    model.captureSelfie(jpeg)
    model.hasConsent = true
    service.failRequirements = true
    await model.save()
    #expect(service.saves == 0)
    #expect(!model.isSaved)
    #expect(model.photos.isComplete)
    #expect(model.errorMessage != nil)
}

@Test func profileOnlyStillRejectsInvalidAndOversizedImages() throws {
    let requirements = PhotoRequirements(reviewRequired: false)
    #expect(throws: PhotoValidationError.self) {
        try PrivatePhotos(profile: Data([0])).validate(requirements: requirements)
    }
    #expect(throws: PhotoValidationError.self) {
        try PrivatePhotos(profile: Data(repeating: 0, count: PrivatePhotos.maximumFileSize + 1))
            .validate(requirements: requirements)
    }
}

@Test @MainActor func disablingReviewWhileOpenRefreshesConsentAndAllowsProfileOnly() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.hasConsent = true
    service.policy = PhotoRequirements(reviewRequired: false)
    await model.save()
    #expect(service.saves == 0)
    #expect(!model.hasConsent)
    #expect(model.requirements?.reviewRequired == false)
    model.hasConsent = true
    await model.save()
    #expect(model.isSaved)
    #expect(service.stored.selfie == nil)
}
