import NewToTownCore
import SwiftUI
import UIKit

/// Own-profile presentation; the signed-in shell owns navigation and account actions.
struct ProfileHomeView: View {
    @Bindable var model: OnboardingModel
    let photoService: (any PhotoService)?
    let isSelected: Bool
    private let interestsService: (any InterestsService)?
    @State private var interests: InterestsModel?
    private enum Editor: String, Identifiable {
        case photos, interests, profile
        var id: String { rawValue }
    }
    @State private var editor: Editor?
    @State private var profilePhotos: [UIImage] = []
    @State private var photoIsMissing = false
    @State private var photoFailed = false
    @State private var photoNeedsReload = true
    @State private var photoLoadGeneration = 0

    init(
        model: OnboardingModel, photoService: (any PhotoService)?, isSelected: Bool,
        interestsService: (any InterestsService)? = nil
    ) {
        self.model = model
        self.photoService = photoService
        self.isSelected = isSelected
        self.interestsService = interestsService
        _interests = State(initialValue: interestsService.map { InterestsModel(service: $0, kind: .profile) })
    }

    var body: some View {
        profile
            .sheet(item: $editor) { destination in
                switch destination {
                case .photos:
                    if let photoService {
                        PhotoSubmissionView(service: photoService, onPhotosSaved: showSavedPhotos)
                    }
                case .interests:
                    if let interestsService {
                        InterestEditorView(service: interestsService, kind: .profile, presentation: .sheet) {}
                    }
                case .profile:
                    ProfileEditorView(account: model)
                }
            }
            .task(id: isSelected && editor == nil) {
                guard isSelected, editor == nil, photoNeedsReload else { return }
                await loadPhoto()
            }
            .task(id: isSelected && editor == nil) {
                if isSelected, editor == nil { await interests?.load() }
            }
            .refreshable {
                await loadPhoto()
                await interests?.load()
            }
    }

    @MainActor private func loadPhoto() async {
        guard let photoService else { return }
        photoLoadGeneration += 1
        let generation = photoLoadGeneration
        photoFailed = false
        do {
            let data = try await photoService.loadProfilePhotos()
            let decoded = try await Task.detached(priority: .utility) {
                try data.map { try ProfileImageDecoder.decode($0, pixels: 1200) }
            }.value
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
            profilePhotos = decoded.map { UIImage(cgImage: $0.cgImage) }
            photoIsMissing = decoded.isEmpty
            photoNeedsReload = false
        } catch {
            // Unknown photo status must not prompt an existing member to add one.
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
            photoFailed = true
        }
    }

    /// The editor already owns the uploaded bytes. Publish them before dismissal
    /// and invalidate older reads instead of downloading the same photos again.
    @MainActor private func showSavedPhotos(_ photos: [Data]) async {
        photoLoadGeneration += 1
        let generation = photoLoadGeneration
        do {
            let decoded = try await Task.detached(priority: .userInitiated) {
                try photos.map { try ProfileImageDecoder.decode($0, pixels: 1200) }
            }.value
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
            profilePhotos = decoded.map { UIImage(cgImage: $0.cgImage) }
            photoIsMissing = decoded.isEmpty
            photoFailed = false
            photoNeedsReload = false
        } catch {
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
            // A successful upload is retained. Fall back to a fresh read on dismissal.
            photoNeedsReload = true
            photoFailed = true
        }
    }

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProfileCard(
                    firstName: model.draft.firstName, jobTitle: model.draft.jobTitle,
                    goal: model.draft.goal, city: "Scottsdale",
                    interests: interests?.snapshot?.profileInterests ?? []
                ) {
                    if !profilePhotos.isEmpty {
                        ProfilePhotoGallery(count: profilePhotos.count) { index in
                            Image(uiImage: profilePhotos[index]).resizable().scaledToFill()
                        }
                    } else {
                        ProfilePhotoFrame {
                            if photoIsMissing {
                                Button("Add a photo", systemImage: "person.crop.rectangle") {
                                    editor = .photos
                                }.foregroundStyle(BrandTheme.secondaryInk)
                            } else if photoFailed {
                                Label("Photo unavailable. Open My photos to try again.", systemImage: "photo")
                                    .font(.callout).padding()
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }

                if photoService != nil {
                    Button("My photos") { editor = .photos }
                        .buttonStyle(BrandActionButtonStyle(tone: .secondary))
                }

                if interestsService != nil {
                    Button("Edit interests") { editor = .interests }
                        .buttonStyle(BrandActionButtonStyle(tone: .secondary))
                        .accessibilityIdentifier("profile.interests")
                }
                Button("Edit profile") { editor = .profile }
                    .buttonStyle(BrandActionButtonStyle(tone: .secondary))
                    .accessibilityIdentifier("profile.edit")
            }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background)
    }
}
