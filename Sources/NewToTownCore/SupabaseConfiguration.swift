import Foundation

/// Public client configuration only. Privileged credentials never belong in the app.
public struct SupabaseConfiguration: Sendable {
    public let projectURL: URL
    public let publishableKey: String

    public enum ConfigurationError: Error, Equatable {
        case invalidProjectURL
        case invalidPublishableKey
    }

    public init(projectURL: String, publishableKey: String) throws {
        guard let url = URL(string: projectURL),
              url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/"
        else {
            throw ConfigurationError.invalidProjectURL
        }

        // Accept the current public-key format, never secret or legacy JWT keys.
        guard publishableKey.hasPrefix("sb_publishable_"),
              publishableKey.count > "sb_publishable_".count,
              !publishableKey.contains(where: { $0.isWhitespace })
        else {
            throw ConfigurationError.invalidPublishableKey
        }

        self.projectURL = url
        self.publishableKey = publishableKey
    }
}
