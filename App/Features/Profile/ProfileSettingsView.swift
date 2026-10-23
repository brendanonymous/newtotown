import NewToTownCore
import SwiftUI

struct ProfileSettingsView: View {
    let personalInfoService: (any PersonalInfoService)?
    let isSelected: Bool
    let isAccountBusy: Bool
    let accountError: String?
    let signOut: @MainActor () async -> Void
    let deleteAccount: () -> Void
    @State private var discovery: DiscoveryModel?
    @Environment(\.scenePhase) private var scenePhase

    init(
        discoveryService: (any DiscoveryService)?,
        personalInfoService: (any PersonalInfoService)?,
        isSelected: Bool,
        isAccountBusy: Bool,
        accountError: String?,
        signOut: @escaping @MainActor () async -> Void,
        deleteAccount: @escaping () -> Void
    ) {
        self.personalInfoService = personalInfoService
        self.isSelected = isSelected
        self.isAccountBusy = isAccountBusy
        self.accountError = accountError
        self.signOut = signOut
        self.deleteAccount = deleteAccount
        _discovery = State(initialValue: discoveryService.map { DiscoveryModel(service: $0) })
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
                if let personalInfoService {
                    NavigationLink {
                        PersonalInfoView(service: personalInfoService)
                    } label: {
                        HStack {
                            Label("Personal info", systemImage: "person.text.rectangle")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                                .foregroundStyle(BrandTheme.secondaryInk)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("settings.personalInfo")
                }
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
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable {
            guard isSelected, !isAccountBusy else { return }
            await discovery?.load()
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
        Text("Privacy").font(.headline)
        if let feed = model.feed {
            Toggle(
                "Show my profile in Discovery",
                isOn: Binding(
                    get: { feed.visible },
                    set: { visible in Task { await model.setVisible(visible) } }
                )
            )
            .tint(BrandTheme.ink)
            .disabled(model.isBusy)
            .accessibilityIdentifier("settings.profileVisibility")
            Text("Allow other members to see your profile and photo in Discovery.")
                .font(.callout).foregroundStyle(BrandTheme.secondaryInk)
            if !feed.visible {
                Label("Your profile is hidden", systemImage: "eye.slash")
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
