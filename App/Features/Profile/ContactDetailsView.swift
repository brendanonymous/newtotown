import NewToTownCore
import SwiftUI

/// Adds a missing sign-in method to the current account after server verification.
struct ContactDetailsView: View {
    @State private var model: ContactDetailsModel
    let onVerified: () -> Void
    @Environment(EmailVerificationRouter.self) private var emailVerification
    @Environment(\.dismiss) private var dismiss

    init(kind: ContactDetailKind, service: any ContactDetailsService, onVerified: @escaping () -> Void) {
        _model = State(initialValue: ContactDetailsModel(kind: kind, service: service))
        self.onVerified = onVerified
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(model.kind == .email ? "Add email" : "Add phone number")
                    .font(.system(.largeTitle, design: .serif))
                if let destination = model.destination {
                    Text(
                        model.kind == .email
                            ? "Open the verification link sent to \(destination.value). You can also enter the code from the email."
                            : "Enter the code sent to \(destination.value)."
                    )
                    .foregroundStyle(BrandTheme.secondaryInk)
                    if model.kind == .email {
                        Button("I’ve verified my email") { Task { await finishEmailVerification() } }
                    }
                    TextField("Verification code", text: $model.code)
                        .keyboardType(.numberPad).textContentType(.oneTimeCode)
                        .accessibilityIdentifier("contact.code")
                    Button("Verify") {
                        Task {
                            if await model.verify() {
                                onVerified()
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(BrandTheme.ink)
                    .foregroundStyle(BrandTheme.background)
                    .accessibilityIdentifier("contact.verify")
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(
                            0, Int(ceil(model.resendAvailableAt.timeIntervalSince(context.date))))
                        let label = model.kind == .email ? "Resend email" : "Resend code"
                        Button(remaining > 0 ? "\(label) in \(remaining)s" : label) {
                            Task { await model.resend() }
                        }
                        .disabled(remaining > 0 || model.isBusy)
                    }
                    Button("Use a different \(model.kind == .email ? "email" : "phone number")") {
                        model.reset()
                    }
                } else {
                    Text(
                        model.kind == .email
                            ? "We’ll send a verification link to add this email to your account."
                            : "We’ll send a code to verify this phone number before adding it to your account."
                    )
                    .foregroundStyle(BrandTheme.secondaryInk)
                    TextField(model.kind == .email ? "Email address" : "Phone number", text: $model.input)
                        .keyboardType(model.kind == .email ? .emailAddress : .phonePad)
                        .textContentType(model.kind == .email ? .emailAddress : .telephoneNumber)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("contact.input")
                    if model.kind == .phone {
                        Text("US numbers can use ten digits. Include the country code for other countries.")
                            .font(.callout).foregroundStyle(BrandTheme.secondaryInk)
                    }
                    Button(model.kind == .email ? "Send verification email" : "Send code") {
                        Task { await model.requestCode() }
                    }
                    .buttonStyle(.borderedProminent).tint(BrandTheme.ink)
                    .foregroundStyle(BrandTheme.background)
                    .accessibilityIdentifier("contact.send")
                }
                if model.isBusy { ProgressView() }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("contact.error")
                }
            }
            .textFieldStyle(BrandTextFieldStyle())
            .disabled(model.isBusy)
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .privacySensitive()
        .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar { BrandNavigationLogo() }.toolbar(.hidden, for: .tabBar)
        .onDisappear {
            // A verification result can temporarily cover this editor.
            if emailVerification.callback == nil { model.reset() }
        }
        .onChange(of: emailVerification.completedCount) { _, _ in
            Task { await finishEmailVerification() }
        }
    }

    private func finishEmailVerification() async {
        if await model.checkEmailVerification() {
            onVerified()
            dismiss()
        }
    }
}
