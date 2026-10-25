import Foundation
import Observation

@MainActor @Observable public final class InterestsModel {
    public let kind: InterestSelectionKind
    public private(set) var snapshot: InterestsSnapshot?
    public private(set) var selected: Set<String> = []
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    private let service: any InterestsService
    private var generation = 0

    public init(service: any InterestsService, kind: InterestSelectionKind) {
        self.service = service
        self.kind = kind
    }
    public var canSave: Bool {
        guard let snapshot else { return false }
        return !isBusy && selected != Set(snapshot.selection(for: kind))
            && snapshot.isValidSelection(selected)
    }
    public func count(in category: InterestCategory) -> Int {
        category.options.filter { selected.contains($0.id) }.count
    }
    public func canToggle(_ optionID: String) -> Bool {
        guard !isBusy,
            let category = snapshot?.categories.first(where: {
                $0.options.contains(where: { $0.id == optionID })
            })
        else { return false }
        return selected.contains(optionID) || count(in: category) < 3
    }
    public func toggle(_ optionID: String) {
        guard canToggle(optionID) else { return }
        if !selected.insert(optionID).inserted { selected.remove(optionID) }
        errorMessage = nil
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
            guard value.isValid else { throw InterestsError.connection }
            snapshot = value
            selected = Set(value.selection(for: kind))
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            errorMessage = message(error)
        }
    }
    @discardableResult public func save() async -> Bool {
        guard canSave, !Task.isCancelled else { return false }
        let current = generation
        let requested = selected
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            let value = try await service.save(requested.sorted(), for: kind)
            guard current == generation, !Task.isCancelled else { return false }
            guard value.isValid, Set(value.selection(for: kind)) == requested else {
                throw InterestsError.connection
            }
            snapshot = value
            return true
        } catch {
            guard current == generation, !Task.isCancelled else { return false }
            errorMessage = message(error)
            return false
        }
    }
    public func reset() {
        generation += 1
        snapshot = nil
        selected = []
        isBusy = false
        errorMessage = nil
    }
    private func message(_ error: Error) -> String {
        switch error as? InterestsError {
        case .signedOut: "Sign in again to update your interests."
        case .invalidSelection: "Choose up to three available interests per category."
        default: "We couldn’t load or save your interests. Please try again."
        }
    }
}
