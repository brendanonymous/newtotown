import NewToTownCore
import SwiftUI

struct OnboardingView: View {
    let model: OnboardingModel?
    let close: () -> Void

    var body: some View {
        NavigationStack {
            if let model {
                OnboardingContent(
                    model: model,
                    close: close
                )
            } else {
                ContentUnavailableView(
                    "Signup is temporarily unavailable", systemImage: "wrench.and.screwdriver",
                    description: Text("Please try again later. You can still explore the welcome screen."))
            }
        }
        .tint(BrandTheme.ink)
    }
}

private struct OnboardingContent: View {
    @Bindable var model: OnboardingModel
    let close: () -> Void
    @State private var code = ""
    @State private var showsDeletionConfirmation = false

    var body: some View {
        signupContent
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(BrandTheme.ink)
            .background(BrandTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.isSignedIn {
                    BrandNavigationLogo()
                }
                if model.step == .signIn || model.step == .code {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: close).disabled(model.isBusy)
                    }
                }
            }
            .alert("Delete your account?", isPresented: $showsDeletionConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete account", role: .destructive) {
                    Task {
                        await model.deleteAccount()
                        if model.step == .signIn { clearSignInFields() }
                    }
                }
            } message: {
                Text(
                    "This permanently deletes your account, private profile, and conversations for both participants. You’ll need to create a new account to use newtotown again."
                )
            }
            .interactiveDismissDisabled(model.isBusy)
    }

    private var signupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch model.step {
                case .loading:
                    ProgressView()
                case .signIn:
                    SignInEntryView(model: model)
                case .code:
                    title(
                        model.signInIdentifier?.isPhone == true ? "Check your texts." : "Check your inbox.",
                        subtitle: "Enter the code below.")
                    TextField("Sign-in code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(BrandTextFieldStyle())
                        .accessibilityIdentifier("signup.code")
                        .disabled(model.isBusy)
                    primary(model.signInIdentifier?.isPhone == true ? "Verify phone" : "Verify email") {
                        await model.verify(code: code)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(
                            0, Int(ceil(model.resendAvailableAt.timeIntervalSince(context.date))))
                        Button(seconds > 0 ? "Resend in \(seconds)s" : "Resend code") {
                            Task { await model.resendCode() }
                        }
                        .disabled(seconds > 0 || model.isBusy)
                    }
                    Button("Use a different number or email") {
                        code = ""
                        model.restartSignIn()
                    }
                    .disabled(model.isBusy)
                case .introduction:
                    FirstSignupIntroduction(isBusy: model.isBusy) {
                        await model.acceptIntroduction()
                    }
                case .profile:
                    title("A little about you.", subtitle: "Give a future friend something to connect with.")
                    ProfileForm(draft: $model.draft)
                        .disabled(model.isBusy)
                    primary("Save my profile") { await model.saveProfile() }
                case .saved:
                    EmptyView()  // AppEntryView routes saved accounts into SignedInView.
                case .restoreFailed:
                    title("Let’s reconnect.", subtitle: "We haven’t changed your saved profile.")
                    primary("Try again") { await model.restore() }
                    accountActions
                }

                if model.isBusy && model.step != .loading {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .accessibilityIdentifier("signup.error")
                }
            }
            .padding(28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button("Sign out") { Task { await signOut() } }
            Button("Delete account", role: .destructive) {
                showsDeletionConfirmation = true
            }
            .accessibilityIdentifier("account.delete")
            .disabled(!model.canDeleteAccount)
        }
        .disabled(model.isBusy)
    }

    private func signOut() async {
        await model.signOut()
        if model.step == .signIn { clearSignInFields() }
    }

    private func clearSignInFields() {
        code = ""
    }

    private func title(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(.largeTitle, design: .serif))
            Text(subtitle).foregroundStyle(BrandTheme.secondaryInk)
        }
    }

    private func primary(_ title: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(18)
                .foregroundStyle(BrandTheme.background)
                .background(BrandTheme.ink, in: RoundedRectangle(cornerRadius: 18))
        }
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.6 : 1)
    }
}
