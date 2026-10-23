import Foundation
import Observation

@MainActor @Observable
public final class DiscoveryPreferencesModel {
    public var minimumAge = "18"
    public var maximumAge = ""
    public private(set) var saved: AgePreferences?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let service: any DiscoveryPreferencesService
    private var generation = 0

    public init(service: any DiscoveryPreferencesService) { self.service = service }

    public var draft: AgePreferences? {
        guard let minimum = Int(minimumAge.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        let maximumText = maximumAge.trimmingCharacters(in: .whitespacesAndNewlines)
        let maximum = maximumText.isEmpty ? nil : Int(maximumText)
        guard maximumText.isEmpty || maximum != nil else { return nil }
        let value = AgePreferences(minimumAge: minimum, maximumAge: maximum)
        return value.isValid ? value : nil
    }
    public var canSave: Bool { saved != nil && draft != nil && draft != saved && !isBusy }
    public var validationMessage: String? {
        saved != nil && draft == nil ? "Enter a valid age range." : nil
    }

    public func load() async {
        guard !isBusy, !Task.isCancelled else { return }
        let current = generation
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            let value = try await service.load()
            guard current == generation, !Task.isCancelled else { return }
            guard value.isValid else { throw DiscoveryPreferencesError.connection }
            saved = value
            minimumAge = String(value.minimumAge)
            maximumAge = value.maximumAge.map(String.init) ?? ""
        } catch {
            guard current == generation else { return }
            errorMessage = message(for: error)
        }
    }

    public func save() async -> Bool {
        guard canSave, let requested = draft, !Task.isCancelled else { return false }
        let current = generation
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            let value = try await service.save(requested)
            guard current == generation, !Task.isCancelled else { return false }
            guard value == requested else { throw DiscoveryPreferencesError.connection }
            saved = value
            return true
        } catch {
            guard current == generation else { return false }
            // A recoverable failure preserves the unsaved range for another attempt.
            errorMessage = message(for: error)
            return false
        }
    }

    public func reset() {
        generation += 1
        saved = nil
        minimumAge = "18"
        maximumAge = ""
        isBusy = false
        errorMessage = nil
    }

    private func message(for error: Error) -> String {
        if error as? DiscoveryPreferencesError == .signedOut {
            return "Sign in again to update your preferences."
        }
        return "We couldn’t update your preferences. Please try again."
    }
}
