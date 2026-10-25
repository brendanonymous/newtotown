import Foundation

/// Recognizes only this app's contact-verification route. Callback tokens are never
/// consumed: the browser verifies with Auth, then the app reads its original owner.
public struct EmailVerificationCallback: Identifiable, Sendable {
    public let id = UUID()
    public let hasError: Bool

    public static func redirectURL(scheme: String) -> URL {
        URL(string: "\(scheme)://auth/email-verified")!
    }

    public init?(url: URL, scheme: String) {
        guard url.scheme == scheme, url.host == "auth", url.path == "/email-verified",
            url.user == nil, url.password == nil, url.port == nil
        else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragment =
            URLComponents(string: "https://callback.invalid/?\(url.fragment ?? "")")?.queryItems ?? []
        hasError = (query + fragment).contains {
            ["error", "error_code", "error_description"].contains($0.name)
        }
    }
}
