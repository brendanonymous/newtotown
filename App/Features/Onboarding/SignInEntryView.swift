import NewToTownCore
import SwiftUI

/// Phone is the signup path. Existing email members can still reach the same account.
struct SignInEntryView: View {
    @Bindable var model: OnboardingModel
    @State private var usesEmail = false
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your next friend\nstarts here.").font(.system(.largeTitle, design: .serif))
            Text(
                usesEmail
                    ? "Sign in to your existing email account."
                    : "Create an account or sign in with a text message code."
            )
            .foregroundStyle(BrandTheme.secondaryInk)
            if usesEmail {
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .textFieldStyle(BrandTextFieldStyle()).accessibilityIdentifier("signup.email")
            } else {
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad).textContentType(.telephoneNumber)
                    .textFieldStyle(BrandTextFieldStyle()).accessibilityIdentifier("signup.phone")
                Text(
                    "US numbers can be entered without +1. For other countries, include + and the country code."
                )
                .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                Text("We’ll text you a sign-in code. Message and data rates may apply.")
                    .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
            }
            Button {
                Task {
                    if usesEmail {
                        await model.requestCode(email: email)
                    } else {
                        await model.requestCode(phone: phone)
                    }
                }
            } label: {
                Text("Send sign-in code").font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(18)
                    .foregroundStyle(BrandTheme.background)
                    .background(BrandTheme.ink, in: RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityIdentifier("signup.sendCode")
            Button(usesEmail ? "Use phone sign-in" : "Already joined with email? Sign in with email") {
                model.restartSignIn()
                phone = ""
                email = ""
                usesEmail.toggle()
            }
            .accessibilityIdentifier("signup.switchMethod")
            if usesEmail {
                Text(
                    "Use email to keep your existing profile. Signing up with an unlinked phone number creates a separate account."
                )
                .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.6 : 1)
    }
}
