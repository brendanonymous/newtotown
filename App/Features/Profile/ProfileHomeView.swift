import NewToTownCore
import SwiftUI
import UIKit

/// Home for a saved profile; signup and account mutation remain in onboarding.
struct ProfileHomeView: View {
    @Bindable var model: OnboardingModel
    let personalInfoService: (any PersonalInfoService)?
    let photoService: (any PhotoService)?
    let discoveryService: (any DiscoveryService)?
    let signOut: @MainActor () async -> Void
    let deleteAccount: () -> Void

    private enum Tab: Hashable { case profile, discovery, settings }
    @State private var selectedTab = Tab.profile
    @State private var showsPhotos = false
    @State private var profilePhoto: UIImage?
    @State private var photoIsMissing = false
    @State private var photoFailed = false

    var body: some View {
        TabView(selection: $selectedTab) {
            profile
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
            if let discoveryService {
                DiscoveryView(service: discoveryService, isSelected: selectedTab == .discovery)
                    .tabItem { Label("Discovery", systemImage: "person.2") }
                    .tag(Tab.discovery)
            }
            ProfileSettingsView(
                discoveryService: discoveryService,
                personalInfoService: personalInfoService,
                isSelected: selectedTab == .settings,
                isAccountBusy: model.isBusy,
                accountError: model.errorMessage,
                signOut: signOut,
                deleteAccount: deleteAccount
            )
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(BrandTheme.ink)
        .sheet(isPresented: $showsPhotos) {
            if let photoService { PhotoSubmissionView(service: photoService) }
        }
        .task(id: selectedTab == .profile && !showsPhotos) {
            profilePhoto = nil
            photoIsMissing = false
            photoFailed = false
            guard selectedTab == .profile, !showsPhotos, let photoService else { return }
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
                ProfileCard(firstName: model.draft.firstName, jobTitle: model.draft.jobTitle,
                            goal: model.draft.goal, city: "Scottsdale") {
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
                    Text("Add your profile photo to get ready. You choose when your profile becomes visible in Scottsdale.")
                        .font(.callout).foregroundStyle(BrandTheme.secondaryInk)
                }
                if photoService != nil {
                    Button("My photos") { showsPhotos = true }
                }
                Button("Edit profile") { model.editProfile() }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background)
    }
}
