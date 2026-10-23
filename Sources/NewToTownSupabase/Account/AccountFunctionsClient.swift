import Foundation
import Supabase

internal enum AccountSessionError: Error { case signedOut }

/// Capture the owner's token before sending. SupabaseClient's default Functions transport
/// can otherwise attach a newer account's session to a request from a dismissed screen.
internal func accountFunctionsClient(
    client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
    session: URLSession
) -> FunctionsClient {
    FunctionsClient(
        url: configuration.projectURL.appendingPathComponent("functions/v1"),
        headers: ["apikey": configuration.publishableKey],
        fetch: { request in
            try Task.checkCancellation()
            let credentials: Session
            do { credentials = try await client.auth.session } catch AuthError.sessionMissing {
                throw AccountSessionError.signedOut
            }
            guard credentials.user.id == accountID else { throw AccountSessionError.signedOut }
            var request = request
            request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
            let response = try await session.data(for: request)
            guard client.auth.currentSession?.user.id == accountID else {
                throw AccountSessionError.signedOut
            }
            return response
        }
    )
}
