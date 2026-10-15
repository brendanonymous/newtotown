import Foundation
import Observation

@MainActor
@Observable
public final class PhotoSubmissionModel {
    public private(set) var photos = PrivatePhotos()
    public private(set) var requirements: PhotoRequirements?
    public private(set) var isBusy = false
    public private(set) var isLoaded = false
    public private(set) var isSaved = false
    public private(set) var errorMessage: String?

    private let service: any PhotoService
    public init(service: any PhotoService) { self.service = service }

    public func load() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let requirements = try await service.requirements()
            photos = try await service.load()
            self.requirements = requirements
            isLoaded = true
            isSaved = photos.meets(requirements)
        } catch {
            errorMessage = "We couldn’t load your photos. Check your connection and try again."
        }
    }

    public func selectProfile(_ data: Data) {
        guard !isBusy else { return }
        photos.profile = data
        changedSelection()
    }

    public func captureSelfie(_ data: Data) {
        guard !isBusy else { return }
        photos.selfie = data
        changedSelection()
    }

    public func showImageError(_ message: String) { errorMessage = message }

    public func save() async {
        guard !isBusy, isLoaded else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            // Refresh before saving: an operator may have changed the flag since opening.
            let requirements = try await service.requirements()
            let requirementsChanged = self.requirements != requirements
            self.requirements = requirements
            isSaved = false
            guard !requirementsChanged else {
                errorMessage = "Photo requirements changed. Check the required photos and try again."
                return
            }
            try photos.validate(requirements: requirements)
            let submission = PrivatePhotos(
                profile: photos.profile,
                selfie: requirements.reviewRequired ? photos.selfie : nil
            )
            try await service.save(submission)
            isSaved = true
        } catch let error as PhotoValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "We couldn’t finish saving your photos. Your selections are still here—try again."
        }
    }

    public func remove() async {
        guard !isBusy, isLoaded else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        isSaved = false
        do {
            try await service.remove()
            photos = PrivatePhotos()
            isSaved = false
        } catch {
            errorMessage = "We couldn’t confirm photo removal. Try again to remove any remaining files."
        }
    }

    private func changedSelection() {
        isSaved = false
        errorMessage = nil
    }
}
