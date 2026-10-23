import Foundation
import Observation

@MainActor @Observable
public final class ReportProfileModel {
    public var reason: ReportReason?
    public var details = ""
    public private(set) var isSending = false
    public private(set) var receiptID: UUID?
    public private(set) var pending: ProfileReport?
    public private(set) var errorMessage: String?
    private let targetID: UUID
    private let service: any ProfileReportingService
    private var generation = 0

    public init(targetID: UUID, service: any ProfileReportingService) {
        self.targetID = targetID
        self.service = service
    }

    public var canSubmit: Bool {
        !isSending && receiptID == nil && reason != nil
            && details.unicodeScalars.count <= ProfileReport.maximumDetailsLength
            && !details.contains("\0")
    }

    public func submit() async {
        guard !isSending, receiptID == nil, !Task.isCancelled else { return }
        if pending == nil {
            guard canSubmit, let reason else { return }
            let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
            pending = ProfileReport(
                targetID: targetID, reason: reason, details: trimmed.isEmpty ? nil : trimmed)
        }
        guard let pending else { return }
        let current = generation
        isSending = true
        errorMessage = nil
        defer { if current == generation { isSending = false } }
        do {
            let receipt = try await service.submit(pending)
            guard current == generation, !Task.isCancelled else { return }
            receiptID = receipt
            self.pending = nil
        } catch {
            guard current == generation else { return }
            // Keep exactly the same request and retry ID after an uncertain response.
            errorMessage =
                error as? ProfileReportingError == .unavailable
                ? "This connection is no longer available to report."
                : "We couldn’t confirm your report. Try again to check its submission."
        }
    }

    public func reset() {
        generation += 1
        reason = nil
        details = ""
        isSending = false
        receiptID = nil
        pending = nil
        errorMessage = nil
    }
}
