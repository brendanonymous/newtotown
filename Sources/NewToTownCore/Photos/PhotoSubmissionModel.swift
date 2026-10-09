import Foundation
import Observation

@MainActor
@Observable
public final class PhotoSubmissionModel {
    public private(set) var photos = PrivatePhotos()
    public private(set) var isBusy = false
    public private(set) var isLoaded = false
    public private(set) var isSaved = false
    public private(set) var errorMessage: String?
    public var hasConsent = false

    private let service: any PhotoService
    public init(service: any PhotoService) { self.service = service }

    public func load() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            photos = try await service.load()
            isLoaded = true
            isSaved = photos.isComplete
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
        guard hasConsent else {
            errorMessage = "Please agree to private photo storage before uploading."
            return
        }
        do { try photos.validate() }
        catch { errorMessage = error.localizedDescription; return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await service.save(photos)
            isSaved = true
            hasConsent = false
        } catch {
            errorMessage = "We couldn’t finish saving both photos. Some may have uploaded. Your selections are still here—try again."
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
            hasConsent = false
        } catch {
            errorMessage = "We couldn’t confirm photo removal. Try again to remove any remaining files."
        }
    }

    private func changedSelection() {
        isSaved = false
        hasConsent = false
        errorMessage = nil
    }
}
