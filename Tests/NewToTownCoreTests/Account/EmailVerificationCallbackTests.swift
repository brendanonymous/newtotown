import Foundation
import Testing

@testable import NewToTownCore

@Test func verificationCallbackRequiresTheCurrentAppsExactRoute() {
    let scheme = "com.newtotown.ios.test"
    let url = EmailVerificationCallback.redirectURL(scheme: scheme)
    #expect(url.absoluteString == "com.newtotown.ios.test://auth/email-verified")
    #expect(EmailVerificationCallback(url: url, scheme: scheme)?.hasError == false)
    for wrong in [
        "com.newtotown.ios://auth/email-verified", "https://auth/email-verified",
        "com.newtotown.ios.test://other/email-verified", "com.newtotown.ios.test://auth/sign-in",
        "com.newtotown.ios.test://member@auth/email-verified",
    ] {
        #expect(EmailVerificationCallback(url: URL(string: wrong)!, scheme: scheme) == nil)
    }
}

@Test func verificationCallbackRecognizesQueryAndFragmentErrorsWithoutTrustingTokens() {
    let base = "com.newtotown.ios://auth/email-verified"
    for suffix in ["?error=access_denied", "#error_code=otp_expired", "#error_description=Expired"] {
        #expect(
            EmailVerificationCallback(url: URL(string: base + suffix)!, scheme: "com.newtotown.ios")?.hasError
                == true)
    }
    #expect(
        EmailVerificationCallback(
            url: URL(string: base + "#access_token=untrusted&refresh_token=untrusted")!,
            scheme: "com.newtotown.ios")?.hasError == false)
}
