import NewToTownCore
import SwiftUI

/// Observe presentation state in a View, rather than the App's Scene builder.
/// This host survives account routing changes and receives cold and warm URL opens.
struct EmailVerificationPresentation: ViewModifier {
    @Bindable var router: EmailVerificationRouter
    let account: OnboardingModel?
    let makeService: (@Sendable (UUID) -> any ContactDetailsService)?

    func body(content: Content) -> some View {
        content
            .environment(router)
            .onOpenURL { url in
                router.receive(url, scheme: Bundle.main.bundleIdentifier ?? "com.newtotown.ios")
            }
            .sheet(item: $router.callback) { callback in
                EmailVerificationResultView(
                    callback: callback, accountID: account?.accountID,
                    isRestoring: account?.step == .loading, makeService: makeService,
                    onVerified: { router.completedCount += 1 }
                )
                .id(callback.id)
            }
    }
}
