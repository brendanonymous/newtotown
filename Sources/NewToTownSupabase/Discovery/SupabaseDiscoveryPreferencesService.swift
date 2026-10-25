import Foundation
import NewToTownCore
import Supabase

public final class SupabaseDiscoveryPreferencesService: DiscoveryPreferencesService {
    private let functions: FunctionsClient

    init(
        client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
        session: URLSession = .shared
    ) {
        functions = accountFunctionsClient(
            client: client, accountID: accountID, configuration: configuration, session: session)
    }

    public func load() async throws -> AgePreferences {
        try await invoke(Command(preferences: nil))
    }

    public func save(_ preferences: AgePreferences) async throws -> AgePreferences {
        guard preferences.isValid else { throw DiscoveryPreferencesError.invalidRange }
        return try await invoke(Command(preferences: preferences))
    }

    private func invoke(_ command: Command) async throws -> AgePreferences {
        do {
            let result: AgePreferences = try await functions.invoke(
                "discovery", options: FunctionInvokeOptions(body: command, timeoutInterval: 45))
            guard result.isValid else { throw DiscoveryPreferencesError.connection }
            return result
        } catch {
            if let typed = error as? DiscoveryPreferencesError { throw typed }
            if error is AccountSessionError { throw DiscoveryPreferencesError.signedOut }
            if case FunctionsError.httpError(let status, _) = error {
                if status == 401 { throw DiscoveryPreferencesError.signedOut }
                if status == 400 { throw DiscoveryPreferencesError.invalidRange }
            }
            throw DiscoveryPreferencesError.connection
        }
    }
}

private struct Command: Encodable {
    let preferences: AgePreferences?
    enum CodingKeys: String, CodingKey {
        case action
        case minimumAge = "minimum_age"
        case maximumAge = "maximum_age"
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(preferences == nil ? "preferences" : "save_preferences", forKey: .action)
        if let preferences {
            try values.encode(preferences.minimumAge, forKey: .minimumAge)
            if let maximumAge = preferences.maximumAge {
                try values.encode(maximumAge, forKey: .maximumAge)
            } else {
                try values.encodeNil(forKey: .maximumAge)
            }
        }
    }
}
