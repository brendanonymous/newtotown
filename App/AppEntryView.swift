import NewToTownCore
import SwiftUI

/// Session routing lives at the window root, rather than inside a signup sheet.
struct AppEntryView: View {
    @Bindable var model: OnboardingModel
    let personalInfoService: (any PersonalInfoService)?
    let photoService: (any PhotoService)?
    let discoveryService: (any DiscoveryService)?
    let makeMessagingService: (@Sendable (UUID) -> any MessagingService)?
    var makeDiscoveryPreferencesService: (@Sendable (UUID) -> any DiscoveryPreferencesService)? = nil
    @State private var showsSignup = false

    var body: some View {
        Group {
            if model.step == .saved, let accountID = model.accountID {
                SignedInView(
                    account: model, accountID: accountID, personalInfoService: personalInfoService,
                    photoService: photoService, discoveryService: discoveryService,
                    messagingService: makeMessagingService?(accountID),
                    preferencesService: makeDiscoveryPreferencesService?(accountID)
                )
                .id(accountID)
            } else if showsSignup || model.isSignedIn || model.step == .loading
                || model.step == .restoreFailed
            {
                OnboardingView(
                    model: model
                ) {
                    model.changeEmail()
                    showsSignup = false
                }
            } else {
                NavigationStack {
                    WelcomeView {
                        model.changeEmail()
                        showsSignup = true
                    }
                }
            }
        }
        .onChange(of: model.step) { old, new in
            if new == .email && [.saved, .profile, .introduction, .restoreFailed].contains(old) {
                showsSignup = false
            }
        }
        .task { await model.restore() }
    }
}
