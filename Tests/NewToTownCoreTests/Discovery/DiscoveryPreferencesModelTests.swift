import Testing

@testable import NewToTownCore

@MainActor private final class PreferencesServiceStub: DiscoveryPreferencesService {
    var value = AgePreferences(minimumAge: 25, maximumAge: 45)
    var failsLoad = false
    var failsSave = false
    var holdsSave = false
    var writes: [AgePreferences] = []
    var pending: CheckedContinuation<AgePreferences, Never>?
    let began = AsyncStream<Void>.makeStream()
    func load() throws -> AgePreferences {
        if failsLoad { throw DiscoveryPreferencesError.connection }
        return value
    }
    func save(_ preferences: AgePreferences) async throws -> AgePreferences {
        writes.append(preferences)
        if failsSave { throw DiscoveryPreferencesError.connection }
        if holdsSave {
            return await withCheckedContinuation {
                pending = $0
                began.continuation.yield()
            }
        }
        value = preferences
        return value
    }
}

@Test @MainActor func preferenceEditorLoadsValidatesAndSavesAnUnboundedRange() async {
    let service = PreferencesServiceStub()
    let model = DiscoveryPreferencesModel(service: service)
    #expect(!model.canSave)
    await model.load()
    #expect(model.minimumAge == "25" && model.maximumAge == "45")
    #expect(!model.canSave)
    model.maximumAge = "24"
    #expect(!model.canSave && model.validationMessage != nil)
    model.maximumAge = "not an age"
    #expect(!model.canSave)
    model.minimumAge = "17"
    model.maximumAge = ""
    #expect(!model.canSave)
    model.minimumAge = "30"
    #expect(model.canSave)
    #expect(await model.save())
    #expect(service.value == AgePreferences(minimumAge: 30))
    #expect(!model.canSave)
}

@Test @MainActor func failedPreferenceSavePreservesDraftAndCanRetry() async {
    let service = PreferencesServiceStub()
    let model = DiscoveryPreferencesModel(service: service)
    await model.load()
    model.maximumAge = "50"
    service.failsSave = true
    #expect(!(await model.save()))
    #expect(model.maximumAge == "50" && model.errorMessage != nil && model.canSave)
    service.failsSave = false
    #expect(await model.save())
    #expect(
        service.writes == [
            AgePreferences(minimumAge: 25, maximumAge: 50), AgePreferences(minimumAge: 25, maximumAge: 50),
        ])
}

@Test @MainActor func failedPreferenceLoadDoesNotAllowOverwritingAnUnknownRange() async {
    let service = PreferencesServiceStub()
    service.failsLoad = true
    let model = DiscoveryPreferencesModel(service: service)
    await model.load()
    model.minimumAge = "30"
    #expect(model.saved == nil && !model.canSave && model.errorMessage != nil)
    service.failsLoad = false
    await model.load()
    #expect(model.minimumAge == "25" && model.errorMessage == nil)
}

@Test @MainActor func preferenceResponseCannotRestoreStateAfterReset() async {
    let service = PreferencesServiceStub()
    service.holdsSave = true
    let model = DiscoveryPreferencesModel(service: service)
    await model.load()
    model.maximumAge = "50"
    var started = service.began.stream.makeAsyncIterator()
    let save = Task { await model.save() }
    await started.next()
    model.reset()
    service.pending?.resume(returning: AgePreferences(minimumAge: 25, maximumAge: 50))
    #expect(!(await save.value))
    #expect(model.saved == nil && model.minimumAge == "18" && model.maximumAge.isEmpty)
}
