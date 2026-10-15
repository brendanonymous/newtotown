import NewToTownCore
import NewToTownSupabase
import SwiftUI

@main
struct NewToTownApp: App {
    @State private var onboardingModel: OnboardingModel?
    private let photoService: (any PhotoService)?
    private let discoveryService: (any DiscoveryService)?

    init() {
        // Construct the backend once at the app boundary; feature views receive state.
        var services: SupabaseServices?
        let values = Bundle.main.infoDictionary ?? [:]
        if let url = values["SupabaseProjectURL"] as? String,
           let key = values["SupabasePublishableKey"] as? String,
           let configuration = try? SupabaseConfiguration(projectURL: url, publishableKey: key) {
            services = SupabaseServices(configuration: configuration)
        }
        _onboardingModel = State(initialValue: services.map { OnboardingModel(service: $0.onboarding) })
        photoService = services?.photos
        discoveryService = services?.discovery
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let onboardingModel {
                    AppEntryView(model: onboardingModel, photoService: photoService, discoveryService: discoveryService)
                } else {
                    NavigationStack { WelcomeView(onJoin: nil) }
                }
            }
            .tint(BrandTheme.ink)
            .preferredColorScheme(.light)
        }
    }
}
