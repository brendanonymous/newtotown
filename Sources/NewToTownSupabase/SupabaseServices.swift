import NewToTownCore
import Supabase

/// One client/session shared by the concrete feature services, built at app startup.
public struct SupabaseServices {
    public let onboarding: SupabaseOnboardingService
    public let photos: SupabasePhotoService
    public let discovery: SupabaseDiscoveryService

    public init(configuration: SupabaseConfiguration) {
        let client = SupabaseClient(supabaseURL: configuration.projectURL, supabaseKey: configuration.publishableKey)
        onboarding = SupabaseOnboardingService(client: client)
        photos = SupabasePhotoService(client: client)
        discovery = SupabaseDiscoveryService(client: client)
    }
}
