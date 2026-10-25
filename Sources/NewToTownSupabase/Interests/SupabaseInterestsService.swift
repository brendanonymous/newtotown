import Foundation
import NewToTownCore
import Supabase

public final class SupabaseInterestsService: InterestsService {
    private let functions: FunctionsClient
    init(
        client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
        session: URLSession = .shared
    ) {
        functions = accountFunctionsClient(
            client: client, accountID: accountID, configuration: configuration, session: session)
    }
    public func load() async throws -> InterestsSnapshot { try await invoke(Command()) }
    public func save(_ optionIDs: [String], for kind: InterestSelectionKind) async throws -> InterestsSnapshot
    {
        guard optionIDs.count <= 15, Set(optionIDs).count == optionIDs.count else {
            throw InterestsError.invalidSelection
        }
        return try await invoke(Command(action: "save", selectionKind: kind.rawValue, optionIDs: optionIDs))
    }
    private func invoke(_ command: Command) async throws -> InterestsSnapshot {
        do {
            let result: InterestsSnapshot = try await functions.invoke(
                "interests", options: FunctionInvokeOptions(body: command, timeoutInterval: 45))
            guard result.isValid else { throw InterestsError.connection }
            return result
        } catch {
            if let typed = error as? InterestsError { throw typed }
            if error is AccountSessionError { throw InterestsError.signedOut }
            if case FunctionsError.httpError(let status, _) = error {
                if status == 401 { throw InterestsError.signedOut }
                if status == 400 { throw InterestsError.invalidSelection }
            }
            throw InterestsError.connection
        }
    }
}
private struct Command: Encodable {
    var action = "load"
    var selectionKind: String?
    var optionIDs: [String]?
    enum CodingKeys: String, CodingKey {
        case action
        case selectionKind = "selection_kind"
        case optionIDs = "option_ids"
    }
}
