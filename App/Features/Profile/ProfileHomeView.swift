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
    @State private var profilePhoto: UIImage?
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
                    if let photoService { PhotoSubmissionView(service: photoService) }
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
            let data = try await photoService.loadProfilePhoto()
            let decoded: ProfileImagePixels?
            if let data {
                decoded = try await Task.detached(priority: .utility) {
                    try ProfileImageDecoder.decode(data, pixels: 1200)
                }.value
            } else {
                decoded = nil
            }
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
            profilePhoto = decoded.map { UIImage(cgImage: $0.cgImage) }
            photoIsMissing = decoded == nil
            photoNeedsReload = false
        } catch {
            // Unknown photo status must not prompt an existing member to add one.
            guard !Task.isCancelled, generation == photoLoadGeneration else { return }
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
                    if let profilePhoto {
                        Image(uiImage: profilePhoto).resizable().scaledToFill()
                    } else if photoIsMissing {
                        Button("Add a profile photo", systemImage: "person.crop.rectangle") {
                            photoNeedsReload = true
                            editor = .photos
                        }.foregroundStyle(BrandTheme.secondaryInk)
                    } else if photoFailed {
                        Label("Photo unavailable. Open My photos to try again.", systemImage: "photo")
                            .font(.callout).padding()
                    } else {
                        ProgressView()
                    }
                }

                if photoService != nil {
                    Button("My photos") {
                        photoNeedsReload = true
                        editor = .photos
                    }
                }

                if interestsService != nil {
                    Button("Edit interests") { editor = .interests }
                        .accessibilityIdentifier("profile.interests")
                }
                Button("Edit profile") { editor = .profile }
                    .accessibilityIdentifier("profile.edit")
            }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background)
    }
}
