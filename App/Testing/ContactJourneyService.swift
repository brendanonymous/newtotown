#if DEBUG
    import Foundation
    import NewToTownCore

    /// Offline verification fixture; never sends email or SMS and is absent from release builds.
    actor ContactJourneyService: PersonalInfoService, ContactDetailsService {
        private var info: PersonalInfo
        private var pending: ContactDestination?
        init() {
            let emailAccount = ProcessInfo.processInfo.arguments.contains("--ui-test-email-account")
            info = PersonalInfo(
                email: emailAccount ? "member@example.com" : nil,
                phone: emailAccount ? nil : "+14805550123")
        }
        func load() -> PersonalInfo { info }
        func requestVerification(for destination: ContactDestination) throws {
            guard destination.kind == .email ? info.email == nil : info.phone == nil else {
                throw ContactDetailsError.alreadyProvided
            }
            pending = destination
        }
        func resendVerification(for destination: ContactDestination) throws {
            guard pending == destination else { throw ContactDetailsError.invalidCode }
        }
        func verify(_ destination: ContactDestination, code: String) throws -> PersonalInfo {
            guard pending == destination, code == "123456" else { throw ContactDetailsError.invalidCode }
            info = PersonalInfo(
                email: destination.kind == .email ? destination.value : info.email,
                phone: destination.kind == .phone ? destination.value : info.phone)
            pending = nil
            return info
        }
    }
#endif
