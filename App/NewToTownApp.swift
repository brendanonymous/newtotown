import SwiftUI

@main
struct NewToTownApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WelcomeView()
            }
            .tint(BrandTheme.ink)
            .preferredColorScheme(.light)
        }
    }
}
