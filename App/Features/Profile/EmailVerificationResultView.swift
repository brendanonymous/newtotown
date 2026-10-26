import NewToTownCore
import Observation
import SwiftUI

/// URL delivery is app-wide so verification also works after a cold launch.
/// Do not retain, log, or import any session parameters from the URL.
@MainActor @Observable final class EmailVerificationRouter {
    var callback: EmailVerificationCallback?
    var completedCount = 0

    func receive(_ url: URL, scheme: String) {
        guard let callback = EmailVerificationCallback(url: url, scheme: scheme) else { return }
        self.callback = callback
    }
}

struct EmailVerificationResultView: View {
    let callback: EmailVerificationCallback
    let accountID: UUID?
    let isRestoring: Bool
    let makeService: (@Sendable (UUID) -> any ContactDetailsService)?
    let onVerified: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var verified = false
    @State private var attempt = 0
    @State private var originalAccountID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let message {
                    Image(systemName: verified ? "checkmark.circle" : "envelope")
                        .font(.largeTitle)
                    Text(message).multilineTextAlignment(.center)
                        .accessibilityIdentifier("contact.linkResult")
                    if !verified && !callback.hasError && accountID != nil {
                        Button("Try again") { attempt += 1 }
                    }
                } else {
                    ProgressView("Checking email verification…")
                }
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task(id: CheckID(accountID: accountID, restoring: isRestoring, attempt: attempt)) {
            message = nil
            verified = false
            guard !callback.hasError else {
                message =
                    "This verification link has expired or couldn’t be verified. Request a new email in Personal info."
                return
            }
            guard !isRestoring else { return }
            guard let accountID, let service = makeService?(accountID) else {
                message = "Sign in to the account where you added your email, then check Personal info."
                return
            }
            if let originalAccountID, originalAccountID != accountID {
                message = "Return to the account where you added your email and check Personal info."
                return
            }
            originalAccountID = accountID
            do {
                _ = try await service.confirmedEmail()
                try Task.checkCancellation()
                verified = true
                message = "Email verified successfully."
                onVerified()
            } catch {
                guard !Task.isCancelled else { return }
                message =
                    "We couldn’t confirm this account’s email. Check your connection and try again, or request a new link in Personal info."
            }
        }
    }

    private struct CheckID: Equatable {
        let accountID: UUID?
        let restoring: Bool
        let attempt: Int
    }
}
