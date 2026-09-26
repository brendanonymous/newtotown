import Testing
@testable import NewToTownSupabase

@Test func acceptsPublicClientConfiguration() throws {
    let configuration = try SupabaseConfiguration(
        projectURL: "https://example.supabase.co",
        publishableKey: "sb_publishable_test"
    )
    #expect(configuration.projectURL.host == "example.supabase.co")
    #expect(configuration.publishableKey == "sb_publishable_test")
}

@Test(arguments: ["", "http://example.supabase.co", "https://", "https://user:password@example.com", "https://example.com/api", "https://example.com?key=value"])
func rejectsInvalidProjectURL(_ url: String) {
    #expect(throws: SupabaseConfiguration.ConfigurationError.invalidProjectURL) {
        try SupabaseConfiguration(projectURL: url, publishableKey: "sb_publishable_test")
    }
}

@Test(arguments: ["", "sb_secret_test", "eyJhbGciOiJIUzI1NiJ9.test.signature", "sb_publishable_", "sb_publishable_test\n"])
func rejectsInvalidOrPrivilegedKeys(_ key: String) {
    #expect(throws: SupabaseConfiguration.ConfigurationError.invalidPublishableKey) {
        try SupabaseConfiguration(projectURL: "https://example.supabase.co", publishableKey: key)
    }
}
