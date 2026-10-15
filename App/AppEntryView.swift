import NewToTownCore
import SwiftUI

/// Session routing lives at the window root, rather than inside a signup sheet.
struct AppEntryView: View {
    @Bindable var model: OnboardingModel
    let photoService: (any PhotoService)?
    let discoveryService: (any DiscoveryService)?
    @State private var showsSignup = false

    var body: some View {
        Group {
            if showsSignup || model.isSignedIn || model.step == .loading || model.step == .restoreFailed {
                OnboardingView(model: model, photoService: photoService, discoveryService: discoveryService) {
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
