import Foundation
import NewToTownCore
import Supabase

public final class SupabaseDiscoveryService: DiscoveryService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    public func load() async throws -> DiscoveryFeed { try await invoke(Command(action: "feed")) }
    public func setVisible(_ visible: Bool) async throws -> DiscoveryFeed {
        try await invoke(Command(action: "visibility", enabled: visible))
    }
    public func decide(on profileID: UUID, choice: ConnectionChoice) async throws -> DiscoveryFeed {
        try await invoke(Command(action: "decide", targetID: profileID, choice: choice.rawValue))
    }
    public func block(_ profileID: UUID) async throws -> DiscoveryFeed {
        try await invoke(Command(action: "block", targetID: profileID))
    }
    private func invoke(_ command: Command) async throws -> DiscoveryFeed {
        try await client.functions.invoke("discovery", options: FunctionInvokeOptions(body: command))
    }
}

private struct Command: Encodable {
    let action: String
    var enabled: Bool? = nil
    var targetID: UUID? = nil
    var choice: String? = nil
    enum CodingKeys: String, CodingKey { case action, enabled, choice; case targetID = "target_id" }
}
