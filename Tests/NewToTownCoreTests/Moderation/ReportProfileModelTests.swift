import Foundation
import Testing

@testable import NewToTownCore

@Test @MainActor func reportRetryKeepsOriginalPayloadAndReceipt() async {
    let service = ReportTestService()
    let model = ReportProfileModel(targetID: UUID(), service: service)
    #expect(!model.canSubmit)
    model.reason = .nonPlatonic
    model.details = "  Unwanted romantic messages.  "
    service.fail = true
    await model.submit()
    let pending = model.pending
    #expect(pending?.details == "Unwanted romantic messages.")
    #expect(model.receiptID == nil && model.errorMessage != nil)
    model.details = "Changed"
    model.reason = .spam
    service.fail = false
    await model.submit()
    #expect(service.calls.count == 2 && service.calls[0] == service.calls[1])
    #expect(model.receiptID == pending?.retryID && model.pending == nil && !model.canSubmit)
}

@Test func reportDetailsBoundariesCountUnicodeScalars() {
    let id = UUID()
    #expect(ProfileReport(targetID: id, reason: .other, details: String(repeating: "😀", count: 1000)).isValid)
    #expect(
        !ProfileReport(targetID: id, reason: .other, details: String(repeating: "😀", count: 1001)).isValid)
    #expect(!ProfileReport(targetID: id, reason: .other, details: "bad\0").isValid)
    #expect(ProfileReport(targetID: id, reason: .other, details: nil).isValid)
}

@Test @MainActor func reportResetDiscardsLateReceipt() async {
    let service = ReportTestService()
    var continuation: CheckedContinuation<UUID, Never>?
    service.onSubmit = { _ in await withCheckedContinuation { continuation = $0 } }
    let model = ReportProfileModel(targetID: UUID(), service: service)
    model.reason = .spam
    let send = Task { await model.submit() }
    while continuation == nil { await Task.yield() }
    model.reset()
    continuation?.resume(returning: UUID())
    await send.value
    #expect(model.receiptID == nil && model.pending == nil && model.reason == nil && !model.isSending)
}

@MainActor private final class ReportTestService: ProfileReportingService {
    var fail = false
    var calls: [ProfileReport] = []
    var onSubmit: ((ProfileReport) async -> UUID)?
    func submit(_ report: ProfileReport) async throws -> UUID {
        calls.append(report)
        if let onSubmit { return await onSubmit(report) }
        if fail { throw ProfileReportingError.connection }
        return report.retryID
    }
}
