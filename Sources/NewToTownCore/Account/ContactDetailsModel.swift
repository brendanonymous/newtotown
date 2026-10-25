import Foundation
import Observation

@MainActor @Observable public final class ContactDetailsModel {
    public let kind: ContactDetailKind
    public var input = ""
    public var code = ""
    public private(set) var destination: ContactDestination?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    public private(set) var resendAvailableAt = Date.distantPast
    private let service: any ContactDetailsService
    private let now: () -> Date
    private var generation = 0

    public init(
        kind: ContactDetailKind, service: any ContactDetailsService, now: @escaping () -> Date = { .now }
    ) {
        self.kind = kind
        self.service = service
        self.now = now
    }

    public var canResend: Bool { destination != nil && !isBusy && now() >= resendAvailableAt }
    public func requestCode() async {
        guard !isBusy, destination == nil, !Task.isCancelled else { return }
        guard let requested = ContactDestination(kind: kind, input: input) else {
            errorMessage = kind == .email ? "Enter a valid email address." : "Enter a valid phone number."
            return
        }
        let current = generation
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            try await service.requestVerification(for: requested)
            guard current == generation, !Task.isCancelled else { return }
            destination = requested
            code = ""
            resendAvailableAt = now().addingTimeInterval(60)
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            errorMessage = message(error)
        }
    }

    public func resend() async {
        guard canResend, let destination, !Task.isCancelled else { return }
        let current = generation
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            try await service.resendVerification(for: destination)
            guard current == generation, !Task.isCancelled else { return }
            resendAvailableAt = now().addingTimeInterval(60)
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            errorMessage = message(error)
        }
    }

    public func verify() async -> Bool {
        guard !isBusy, let destination, !Task.isCancelled else { return false }
        let token = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (6...10).contains(token.count), token.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            errorMessage = "Enter the verification code from your latest message."
            return false
        }
        let current = generation
        isBusy = true
        errorMessage = nil
        defer { if current == generation { isBusy = false } }
        do {
            let info = try await service.verify(destination, code: token)
            guard current == generation, !Task.isCancelled else { return false }
            guard destination.matches(info) else { throw ContactDetailsError.invalidCode }
            return true
        } catch {
            guard current == generation, !Task.isCancelled else { return false }
            errorMessage = message(error)
            return false
        }
    }

    public func reset() {
        generation += 1
        input = ""
        code = ""
        destination = nil
        isBusy = false
        errorMessage = nil
        resendAvailableAt = .distantPast
    }

    private func message(_ error: Error) -> String {
        switch error as? ContactDetailsError {
        case .signedOut: "Sign in again to add contact details."
        case .alreadyProvided:
            "This account already has that contact type. Return to Personal info and refresh."
        case .contactInUse:
            "That contact is already attached to an account. Use another contact or sign in to that account."
        case .invalidCode: "That code wasn’t accepted. Check the latest code and try again."
        case .rateLimited: "Please wait before requesting another code."
        default: "We couldn’t complete verification. Check your connection and try again."
        }
    }
}
