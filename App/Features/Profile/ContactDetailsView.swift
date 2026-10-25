import NewToTownCore
import SwiftUI

/// Adds a missing sign-in method to the current account after server verification.
struct ContactDetailsView: View {
    @State private var model: ContactDetailsModel
    let onVerified: () -> Void
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
                    Text("Enter the code sent to \(destination.value).")
                        .foregroundStyle(BrandTheme.secondaryInk)
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
                        Button(remaining > 0 ? "Resend code in \(remaining)s" : "Resend code") {
                            Task { await model.resend() }
                        }
                        .disabled(remaining > 0 || model.isBusy)
                    }
                    Button("Use a different \(model.kind == .email ? "email" : "phone number")") {
                        model.reset()
                    }
                } else {
                    Text("We’ll send a code to verify this contact before adding it to your account.")
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
                    Button("Send code") { Task { await model.requestCode() } }
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
        .onDisappear { model.reset() }
    }
}
