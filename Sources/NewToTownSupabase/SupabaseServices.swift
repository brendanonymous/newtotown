import Foundation
import NewToTownCore
import Supabase

/// One client/session shared by the concrete feature services, built at app startup.
public struct SupabaseServices: Sendable {
    private let client: SupabaseClient
    private let configuration: SupabaseConfiguration
    public let personalInfo: SupabasePersonalInfoService
    public let onboarding: SupabaseOnboardingService
    public let photos: SupabasePhotoService
    public let discovery: SupabaseDiscoveryService

    public func messaging(for accountID: UUID) -> SupabaseMessagingService {
        SupabaseMessagingService(client: client, accountID: accountID, configuration: configuration)
    }

    public init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
        let client = SupabaseClient(
            supabaseURL: configuration.projectURL, supabaseKey: configuration.publishableKey)
        self.client = client
        personalInfo = SupabasePersonalInfoService(client: client)
        onboarding = SupabaseOnboardingService(client: client)
        photos = SupabasePhotoService(client: client)
        discovery = SupabaseDiscoveryService(client: client)
    }
}
