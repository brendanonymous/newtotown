import NewToTownCore
import SwiftUI

struct ProfileSettingsView: View {
    let isSelected: Bool
    let isAccountBusy: Bool
    let accountError: String?
    let signOut: @MainActor () async -> Void
    let deleteAccount: () -> Void
    @State private var discovery: DiscoveryModel?
    @Environment(\.scenePhase) private var scenePhase

    init(service: (any DiscoveryService)?, isSelected: Bool, isAccountBusy: Bool, accountError: String?,
         signOut: @escaping @MainActor () async -> Void, deleteAccount: @escaping () -> Void) {
        self.isSelected = isSelected
        self.isAccountBusy = isAccountBusy
        self.accountError = accountError
        self.signOut = signOut
        self.deleteAccount = deleteAccount
        _discovery = State(initialValue: service.map { DiscoveryModel(service: $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").font(.system(.largeTitle, design: .serif))
                if let discovery {
                    visibility(discovery)
                    Divider()
                }
                Text("Account").font(.headline)
                Button("Sign out") { Task { await signOut() } }
                Button("Delete account", role: .destructive, action: deleteAccount)
                    .accessibilityIdentifier("account.delete")
                if isAccountBusy { ProgressView("Please wait…") }
                if let accountError {
                    Text(accountError).font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("signup.error")
                }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            .disabled(isAccountBusy || discovery?.isBusy == true)
        }
        .background(BrandTheme.background)
        .task(id: isSelected) {
            if isSelected { await discovery?.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if isSelected && phase == .active { Task { await discovery?.load() } }
        }
    }

    @ViewBuilder private func visibility(_ model: DiscoveryModel) -> some View {
        Text("Profile visibility").font(.headline)
        if let feed = model.feed {
            if feed.visible {
                Text("Your profile is visible in Scottsdale.")
                    .foregroundStyle(BrandTheme.secondaryInk)
                Button("Hide my profile") { Task { await model.setVisible(false) } }
                    .accessibilityIdentifier("settings.hideProfile")
            } else {
                Label("Your profile is hidden", systemImage: "eye.slash")
                Text("Join discovery from your profile when you’re ready to be seen.")
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        if model.isBusy { ProgressView("Please wait…") }
        if let error = model.errorMessage {
            Text(error).font(.callout).foregroundStyle(.red)
            Button("Try again") { Task { await model.load() } }
        }
    }
}
