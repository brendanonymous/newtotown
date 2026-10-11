import NewToTownCore
import SwiftUI

/// Home for a saved profile; signup and account mutation remain in onboarding.
struct ProfileHomeView: View {
    @Bindable var model: OnboardingModel
    let photoService: (any PhotoService)?
    let discoveryService: (any DiscoveryService)?
    let signOut: @MainActor () async -> Void
    let deleteAccount: () -> Void

    private enum Tab: Hashable { case profile, settings }
    @State private var selectedTab = Tab.profile
    @State private var showsPhotos = false
    @State private var hasProfilePhoto: Bool?

    var body: some View {
        TabView(selection: $selectedTab) {
            profile
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
            ProfileSettingsView(service: discoveryService, isSelected: selectedTab == .settings,
                isAccountBusy: model.isBusy, accountError: model.errorMessage, signOut: signOut, deleteAccount: deleteAccount)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(BrandTheme.ink)
        .sheet(isPresented: $showsPhotos) {
            if let photoService { PhotoSubmissionView(service: photoService) }
        }
        .task(id: selectedTab == .profile && !showsPhotos) {
            hasProfilePhoto = nil
            guard selectedTab == .profile, !showsPhotos, let photoService else { return }
            do {
                let exists = try await photoService.hasProfilePhoto()
                guard !Task.isCancelled else { return }
                hasProfilePhoto = exists
            } catch {
                // Unknown photo status must not prompt an existing member to add one.
                guard !Task.isCancelled else { return }
                hasProfilePhoto = nil
            }
        }
    }

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("You’re off to\na good start.").font(.system(.largeTitle, design: .serif))
                    Text("Your profile details are saved, \(model.draft.firstName).")
                        .foregroundStyle(BrandTheme.secondaryInk)
                }
                Label("Scottsdale", systemImage: "mappin")
                Text(model.draft.jobTitle).font(.headline)
                Text(model.draft.goal)
                if hasProfilePhoto == false {
                    Text("Add your profile photo to get ready. You choose when your profile becomes visible in Scottsdale.")
                        .font(.callout).foregroundStyle(BrandTheme.secondaryInk)
                }
                if photoService != nil {
                    Button("My photos") { showsPhotos = true }
                }
                if let discoveryService {
                    NavigationLink("Discover local friends") { DiscoveryView(service: discoveryService) }
                }
                Button("Edit profile") { model.editProfile() }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            .disabled(model.isBusy)
        }
        .background(BrandTheme.background)
    }
}
