import NewToTownCore
import SwiftUI
import UIKit

/// Own-profile presentation; the signed-in shell owns navigation and account actions.
struct ProfileHomeView: View {
    @Bindable var model: OnboardingModel
    let photoService: (any PhotoService)?
    let isSelected: Bool
    @State private var showsPhotos = false
    @State private var profilePhoto: UIImage?
    @State private var photoIsMissing = false
    @State private var photoFailed = false

    var body: some View {
        profile
            .sheet(isPresented: $showsPhotos) {
                if let photoService { PhotoSubmissionView(service: photoService) }
            }
            .task(id: isSelected && !showsPhotos) {
                profilePhoto = nil
                photoIsMissing = false
                photoFailed = false
                guard isSelected, !showsPhotos, let photoService else { return }
                do {
                    let data = try await photoService.loadProfilePhoto()
                    guard !Task.isCancelled else { return }
                    if let data {
                        profilePhoto = UIImage(data: data)
                        photoFailed = profilePhoto == nil
                    } else {
                        photoIsMissing = true
                    }
                } catch {
                    // Unknown photo status must not prompt an existing member to add one.
                    guard !Task.isCancelled else { return }
                    photoFailed = true
                }
            }
    }

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProfileCard(
                    firstName: model.draft.firstName, jobTitle: model.draft.jobTitle,
                    goal: model.draft.goal, city: "Scottsdale"
                ) {
                    if let profilePhoto {
                        Image(uiImage: profilePhoto).resizable().scaledToFill()
                    } else if photoIsMissing {
                        Label("Add a profile photo", systemImage: "person.crop.rectangle")
                            .foregroundStyle(BrandTheme.secondaryInk)
                    } else if photoFailed {
                        Label("Photo unavailable. Open My photos to try again.", systemImage: "photo")
                            .font(.callout).padding()
                    } else {
                        ProgressView()
                    }
                }
                if photoIsMissing {
                    Text(
                        "Add your profile photo to get ready. You choose when your profile becomes visible in Scottsdale."
                    )
                    .font(.callout).foregroundStyle(BrandTheme.secondaryInk)
                }
                if photoService != nil {
                    Button("My photos") { showsPhotos = true }
                }
                Button("Edit profile") { model.editProfile() }
            }
            .padding(28).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background)
    }
}
