import NewToTownCore
import Supabase

public final class SupabasePersonalInfoService: PersonalInfoService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    public func load() async throws -> PersonalInfo {
        // Fetch the current Auth user instead of showing possibly stale session data.
        let user = try await client.auth.user()
        return PersonalInfo(email: user.email, phone: user.phone)
    }
}
