import Foundation

/// US numbers may be entered locally; international numbers require an explicit country code.
/// This checks format, not ownership or reachability. Only the server-verified OTP proves control.
public struct PhoneNumber: RawRepresentable, Equatable, Sendable {
    public let rawValue: String

    public init?(rawValue input: String) {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = CharacterSet(charactersIn: " ()-.")
        guard
            input.unicodeScalars.allSatisfy({
                $0.isASCII && (separators.contains($0) || $0 == "+" || ("0"..."9").contains($0))
            })
        else { return nil }
        let compact = String(input.unicodeScalars.filter { !separators.contains($0) })
        let normalized: String
        if compact.hasPrefix("+") {
            normalized = compact
        } else if compact.count == 10 {
            normalized = "+1" + compact
        } else if compact.count == 11 && compact.hasPrefix("1") {
            normalized = "+" + compact
        } else {
            return nil
        }
        guard normalized.range(of: #"^\+[1-9][0-9]{7,14}$"#, options: .regularExpression) != nil else {
            return nil
        }
        rawValue = normalized
    }
}

public enum SignInIdentifier: Equatable, Sendable {
    case email(String)
    case phone(PhoneNumber)

    public var value: String {
        switch self {
        case .email(let email): email
        case .phone(let number): number.rawValue
        }
    }

    public var isPhone: Bool {
        if case .phone = self { return true }
        return false
    }
}
