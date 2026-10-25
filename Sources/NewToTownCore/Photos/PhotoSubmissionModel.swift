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
    public private(set) var hasStoredPhotos = false

    public var canSave: Bool {
        guard let requirements else { return false }
        return isLoaded && !isBusy && !isSaved && photos.meets(requirements)
    }
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
            hasStoredPhotos = !photos.profilePhotos.isEmpty || photos.selfie != nil
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

    public func addProfile(_ data: Data) {
        guard !isBusy else { return }
        guard photos.profilePhotos.count < PrivatePhotos.maximumProfilePhotos else {
            errorMessage = PhotoValidationError.tooManyPhotos.localizedDescription
            return
        }
        if photos.profile == nil { photos.profile = data } else { photos.additionalProfiles.append(data) }
        changedSelection()
    }

    public func replaceProfile(at index: Int, with data: Data) {
        guard !isBusy, photos.profilePhotos.indices.contains(index) else { return }
        if index == 0 { photos.profile = data } else { photos.additionalProfiles[index - 1] = data }
        changedSelection()
    }

    /// Removing the main photo promotes the next photo. Remove-all remains a
    /// separate, confirmed server action so an empty draft cannot look saved.
    public func removeProfile(at index: Int) {
        var remaining = photos.profilePhotos
        guard !isBusy, remaining.count > 1, remaining.indices.contains(index) else { return }
        remaining.remove(at: index)
        photos.profile = remaining.first
        photos.additionalProfiles = Array(remaining.dropFirst())
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
                selfie: requirements.reviewRequired ? photos.selfie : nil,
                additionalProfiles: photos.additionalProfiles
            )
            try await service.save(submission)
            hasStoredPhotos = true
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
            hasStoredPhotos = false
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
