import NewToTownCore
import SwiftUI

/// The signed-in shell owns tabs and navigation; onboarding owns signup/profile editing.
struct SignedInView: View {
    @Bindable var account: OnboardingModel
    let accountID: UUID
    let personalInfoService: (any PersonalInfoService)?
    let photoService: (any PhotoService)?
    let discoveryService: (any DiscoveryService)?
    let messagingService: (any MessagingService)?
    let preferencesService: (any DiscoveryPreferencesService)?
    let reportingService: (any ProfileReportingService)?
    @State private var discoveryRevision = 0
    @State private var reportedProfileIDs: Set<UUID> = []
    @State private var profileImages = ProfileImageStore()
    @Environment(\.profileImages) private var suppliedProfileImages
    private var activeProfileImages: ProfileImageStore { suppliedProfileImages ?? profileImages }
    private enum Tab: Hashable { case profile, discovery, connections, messages }
    @State private var selectedTab = Tab.profile
    @State private var confirmsDeletion = false

    var body: some View {
        TabView(selection: $selectedTab) {

            if let discoveryService {
                NavigationStack {
                    DiscoveryView(
                        service: discoveryService, isSelected: selectedTab == .discovery,
                        reportedProfileIDs: reportedProfileIDs
                    )
                    .id(discoveryRevision)
                    .navigationTitle("").navigationBarTitleDisplayMode(.inline)
                    .toolbar { BrandNavigationLogo() }
                }
                .tabItem { Label("Discovery", systemImage: "person.2") }.tag(Tab.discovery)
                NavigationStack {
                    ConnectionsView(
                        service: discoveryService, accountID: accountID,
                        messagingService: messagingService, reportingService: reportingService,
                        isSelected: selectedTab == .connections, reportedProfileIDs: reportedProfileIDs,
                        onReportSubmitted: { reportedProfileIDs.insert($0) }
                    )
                    .navigationTitle("").navigationBarTitleDisplayMode(.inline)
                    .toolbar { BrandNavigationLogo() }
                }
                .tabItem { Label("Connections", systemImage: "hands.clap.fill") }.tag(Tab.connections)
            }

            if let messagingService {
                NavigationStack {
                    ConversationListView(
                        accountID: accountID, service: messagingService, isSelected: selectedTab == .messages,
                        reportingService: reportingService, reportedProfileIDs: reportedProfileIDs,
                        onReportSubmitted: { reportedProfileIDs.insert($0) }
                    )
                    .navigationTitle("").navigationBarTitleDisplayMode(.inline)
                    .toolbar { BrandNavigationLogo() }
                }
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }.tag(
                    Tab.messages)
            }
            NavigationStack {
                ProfileHomeView(
                    model: account, photoService: photoService, isSelected: selectedTab == .profile
                )
                .navigationTitle("").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    BrandNavigationLogo()
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let preferencesService {
                            NavigationLink {
                                DiscoveryPreferencesView(service: preferencesService) {
                                    discoveryRevision += 1
                                }
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                            .accessibilityLabel("Preferences")
                            .accessibilityIdentifier("profile.preferences")
                        }
                        NavigationLink {
                            ProfileSettingsView(
                                discoveryService: discoveryService, personalInfoService: personalInfoService,
                                isSelected: true, isAccountBusy: account.isBusy,
                                accountError: account.errorMessage, signOut: { await account.signOut() },
                                deleteAccount: { confirmsDeletion = true }
                            )
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { BrandNavigationLogo() }
                            .toolbar(.hidden, for: .tabBar)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("profile.settings")
                    }
                }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(Tab.profile)
        }
        .tint(BrandTheme.ink)
        .environment(\.profileImages, activeProfileImages)
        .onChange(of: reportedProfileIDs) { _, ids in activeProfileImages.exclude(ids) }
        .onDisappear { activeProfileImages.clear() }
        .foregroundStyle(BrandTheme.ink)
        .alert("Delete your account?", isPresented: $confirmsDeletion) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) { Task { await account.deleteAccount() } }
        } message: {
            Text(
                "This permanently deletes your account, profile, and conversations for both participants.")
        }
    }
}
