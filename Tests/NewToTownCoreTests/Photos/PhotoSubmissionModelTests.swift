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
    func loadProfilePhotos() async throws -> [Data] { stored.profilePhotos }
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

@Test @MainActor func photosSaveWithoutRepeatedAgreement() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    model.captureSelfie(jpeg)
    await model.save()
    #expect(service.saves == 1)
    #expect(model.isSaved)
    #expect(service.stored.isComplete)
}

@Test @MainActor func photoValidationStopsMissingOversizedAndInvalidFiles() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    await model.save()
    #expect(service.saves == 0)
    model.captureSelfie(Data([0, 1, 2]))
    await model.save()
    #expect(service.saves == 0)
    model.captureSelfie(Data(repeating: 0, count: PrivatePhotos.maximumFileSize + 1))
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
    service.failSave = true
    await model.save()
    #expect(!model.isSaved)
    #expect(model.photos.isComplete)
    #expect(!model.isBusy)
    service.failSave = false
    await model.save()
    #expect(model.isSaved)
}

@Test @MainActor func restoresPrivatePhotosAndReplacementCanSaveWithoutRepeatedConsent() async {
    let service = TestPhotoService()
    service.stored = PrivatePhotos(profile: jpeg, selfie: jpeg)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    #expect(model.isSaved)
    model.captureSelfie(jpeg)
    #expect(!model.isSaved)
    await model.save()
    #expect(model.isSaved)
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
    await model.save()
    #expect(model.isSaved)
    #expect(service.stored.profile == jpeg)
    #expect(service.stored.selfie == nil)
    model.captureSelfie(jpeg)
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
    service.policy = PhotoRequirements(reviewRequired: true)
    await model.save()
    #expect(service.saves == 0)
    #expect(model.requirements?.reviewRequired == true)
    #expect(!model.isSaved)
    #expect(model.photos.profile == jpeg)
    model.captureSelfie(jpeg)
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

@Test @MainActor func disablingReviewWhileOpenRefreshesRequirementsAndAllowsProfileOnly() async {
    let service = TestPhotoService()
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.selectProfile(jpeg)
    service.policy = PhotoRequirements(reviewRequired: false)
    await model.save()
    #expect(service.saves == 0)
    #expect(model.requirements?.reviewRequired == false)
    await model.save()
    #expect(model.isSaved)
    #expect(service.stored.selfie == nil)
}

@Test @MainActor func photoActionsReflectSelectionAndPersistedFiles() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    #expect(!model.canSave && !model.hasStoredPhotos)
    await model.load()
    #expect(!model.canSave && !model.hasStoredPhotos)
    model.selectProfile(jpeg)
    #expect(model.canSave && !model.hasStoredPhotos)
    service.failSave = true
    await model.save()
    #expect(model.canSave && !model.hasStoredPhotos)
    service.failSave = false
    await model.save()
    #expect(!model.canSave && model.hasStoredPhotos)
    model.selectProfile(jpeg)
    #expect(model.canSave && model.hasStoredPhotos)
    service.failRemove = true
    await model.remove()
    #expect(model.hasStoredPhotos)
    service.failRemove = false
    await model.remove()
    #expect(!model.canSave && !model.hasStoredPhotos)
}

@Test @MainActor func galleryCapsAtThreeAndPromotesTheNextPhotoWhenRemovingMain() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    let second = Data([0xff, 0xd8, 0xff, 0x02, 0xff, 0xd9])
    let third = Data([0xff, 0xd8, 0xff, 0x03, 0xff, 0xd9])
    for data in [jpeg, second, third, jpeg] { model.addProfile(data) }
    #expect(model.photos.profilePhotos == [jpeg, second, third])
    #expect(model.errorMessage != nil)
    model.removeProfile(at: 0)
    #expect(model.photos.profile == second)
    #expect(model.photos.profilePhotos == [second, third])
    model.replaceProfile(at: 1, with: jpeg)
    await model.save()
    #expect(model.isSaved)
    #expect(service.stored.profilePhotos == [second, jpeg])
    #expect(service.stored.selfie == nil)
}

@Test @MainActor func invalidAdditionalPhotoAndFourPhotoServiceSubmissionsAreRejected() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.addProfile(jpeg)
    model.addProfile(Data([0, 1]))
    await model.save()
    #expect(service.saves == 0 && !model.isSaved)
    #expect(throws: PhotoValidationError.tooManyPhotos) {
        try PrivatePhotos(profile: jpeg, additionalProfiles: [jpeg, jpeg, jpeg])
            .validate(requirements: PhotoRequirements(reviewRequired: false))
    }
}

@Test @MainActor func galleryDraftSurvivesFailedSaveAndOnePhotoCannotBeRemovedAccidentally() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    service.stored = PrivatePhotos(profile: jpeg)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.removeProfile(at: 0)
    #expect(model.photos.profilePhotos.count == 1)
    model.addProfile(jpeg)
    model.addProfile(jpeg)
    service.failSave = true
    await model.save()
    #expect(model.photos.profilePhotos.count == 3 && !model.isSaved)
    service.failSave = false
    await model.save()
    #expect(service.stored.profilePhotos.count == 3 && model.isSaved)
}

@Test @MainActor func removingTheLastUnsavedPhotoOnlyClearsTheLocalDraft() async {
    let service = TestPhotoService()
    service.policy = PhotoRequirements(reviewRequired: false)
    let model = PhotoSubmissionModel(service: service)
    await model.load()
    model.addProfile(jpeg)
    model.removeProfile(at: 0)
    #expect(model.photos.profilePhotos.isEmpty)
    #expect(!model.canSave && !model.hasStoredPhotos && !model.isSaved)
    #expect(service.saves == 0 && service.stored.profile == nil)
}
