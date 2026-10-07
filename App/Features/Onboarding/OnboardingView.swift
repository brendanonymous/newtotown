import NewToTownCore
import SwiftUI

struct OnboardingView: View {
    let model: OnboardingModel?

    var body: some View {
        NavigationStack {
            if let model {
                OnboardingContent(model: model)
            } else {
                ContentUnavailableView("Signup isn’t configured", systemImage: "wrench.and.screwdriver", description: Text("This build needs its backend connection settings. You can still explore the welcome screen."))
            }
        }
        .tint(BrandTheme.ink)
    }
}

private struct OnboardingContent: View {
    @Bindable var model: OnboardingModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var showsDeletionConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch model.step {
                case .loading:
                    ProgressView("Loading your account…")
                case .email:
                    title("Your next friend\nstarts here.", subtitle: "Create an account or sign in with an email code. For men aged 18+ in Scottsdale.")
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("signup.email")
                        .disabled(model.isBusy)
                    primary("Send sign-in code") { await model.requestCode(email: email) }
                case .code:
                    title("Check your inbox.", subtitle: "Enter the code sent to \(model.email). Check spam if you don’t see it.")
                    TextField("Email code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("signup.code")
                        .disabled(model.isBusy)
                    primary("Verify email") { await model.verify(code: code) }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(0, Int(ceil(model.resendAvailableAt.timeIntervalSince(context.date))))
                        Button(seconds > 0 ? "Resend in \(seconds)s" : "Resend code") {
                            Task { await model.resendCode() }
                        }
                        .disabled(seconds > 0 || model.isBusy)
                    }
                    Button("Use a different email") {
                        code = ""
                        model.changeEmail()
                    }
                    .disabled(model.isBusy)
                case .profile:
                    title("A little about you.", subtitle: "Give a future friend something to connect with.")
                    ProfileForm(draft: $model.draft)
                        .disabled(model.isBusy)
                    primary("Save my profile") { await model.saveProfile() }
                    accountActions
                case .saved:
                    title("You’re off to\na good start.", subtitle: "Your profile details are saved, \(model.draft.firstName).")
                    Label("Scottsdale", systemImage: "mappin")
                    Text(model.draft.jobTitle).font(.headline)
                    Text(model.draft.goal)
                    Text("Next up: your profile photo and verification selfie. That step is coming in the next build. Your profile is private and isn’t available in discovery.")
                        .font(.callout)
                        .foregroundStyle(BrandTheme.secondaryInk)
                    Button("Edit profile") { model.editProfile() }
                        .disabled(model.isBusy)
                    accountActions
                case .restoreFailed:
                    title("Let’s reconnect.", subtitle: "We haven’t changed your saved profile.")
                    primary("Try again") { await model.restore() }
                    accountActions
                }

                if model.isBusy { ProgressView().frame(maxWidth: .infinity) }
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
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
        .navigationTitle("newtotown")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }.disabled(model.isBusy)
            }
        }
        .alert("Delete your account?", isPresented: $showsDeletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                Task {
                    await model.deleteAccount()
                    if model.step == .email {
                        email = ""
                        code = ""
                    }
                }
            }
        } message: {
            Text("This permanently deletes your account and private profile. You’ll need to create a new account to use newtotown again.")
        }
        .interactiveDismissDisabled(model.isBusy)
        .task { await model.restore() }
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button("Sign out") {
                Task {
                    await model.signOut()
                    if model.step == .email {
                        email = ""
                        code = ""
                    }
                }
            }
            Button("Delete account", role: .destructive) {
                showsDeletionConfirmation = true
            }
            .accessibilityIdentifier("account.delete")
            .disabled(!model.canDeleteAccount)
        }
        .disabled(model.isBusy)
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
