import Observation

@MainActor @Observable
public final class PersonalInfoModel {
    public private(set) var info: PersonalInfo?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let service: any PersonalInfoService

    public init(service: any PersonalInfoService) { self.service = service }

    public func load() async {
        guard !isBusy, !Task.isCancelled else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let loaded = try await service.load()
            guard !Task.isCancelled else {
                finishCancellation()
                return
            }
            info = loaded
        } catch {
            if Task.isCancelled {
                finishCancellation()
            } else {
                info = nil
                errorMessage = "We couldn’t load your personal info. Check your connection and try again."
            }
        }
    }

    private func finishCancellation() {
        if info == nil {
            errorMessage = "Loading was interrupted. Pull down to refresh or try again."
        }
    }
}
