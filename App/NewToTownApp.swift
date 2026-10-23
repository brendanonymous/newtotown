import NewToTownCore
import NewToTownSupabase
import SwiftUI

@main
struct NewToTownApp: App {
    @State private var onboardingModel: OnboardingModel?
    private let personalInfoService: (any PersonalInfoService)?
    private let photoService: (any PhotoService)?
    private let discoveryService: (any DiscoveryService)?

    private let makeDiscoveryPreferencesService: (@Sendable (UUID) -> any DiscoveryPreferencesService)?
    private let makeMessagingService: (@Sendable (UUID) -> any MessagingService)?

    private let makeReportingService: (@Sendable (UUID) -> any ProfileReportingService)?

    init() {
        // Construct the backend once at the app boundary; feature views receive state.
        var services: SupabaseServices?
        let values = Bundle.main.infoDictionary ?? [:]
        if let url = values["SupabaseProjectURL"] as? String,
            let key = values["SupabasePublishableKey"] as? String,
            let configuration = try? SupabaseConfiguration(projectURL: url, publishableKey: key)
        {
            services = SupabaseServices(configuration: configuration)
        }
        _onboardingModel = State(initialValue: services.map { OnboardingModel(service: $0.onboarding) })
        personalInfoService = services?.personalInfo
        photoService = services?.photos
        discoveryService = services?.discovery
        if let shared = services {
            makeReportingService = { @Sendable (accountID: UUID) -> any ProfileReportingService in
                shared.reporting(for: accountID)
            }
            makeDiscoveryPreferencesService = {
                @Sendable (accountID: UUID) -> any DiscoveryPreferencesService in
                shared.discoveryPreferences(for: accountID)
            }
            makeMessagingService = { @Sendable (accountID: UUID) -> any MessagingService in
                shared.messaging(for: accountID)
            }
        } else {
            makeReportingService = nil
            makeMessagingService = nil
            makeDiscoveryPreferencesService = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-messaging") {
                        MessagingJourneyFixture()
                    } else {
                        productionContent
                    }
                #else
                    productionContent
                #endif
            }
            .tint(BrandTheme.ink)
            .preferredColorScheme(.light)
        }
    }

    @ViewBuilder private var productionContent: some View {
        if let onboardingModel {
            AppEntryView(
                model: onboardingModel, personalInfoService: personalInfoService,
                photoService: photoService, discoveryService: discoveryService,
                makeMessagingService: makeMessagingService,
                makeDiscoveryPreferencesService: makeDiscoveryPreferencesService,
                makeReportingService: makeReportingService)
        } else {
            NavigationStack { WelcomeView(onJoin: nil) }
        }
    }
}
