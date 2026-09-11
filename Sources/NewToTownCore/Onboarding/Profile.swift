import Foundation

public struct Profile: Codable, Equatable, Sendable {
    public let id: UUID
    public let firstName: String
    public let jobTitle: String
    public let goal: String
    public let dateOfBirth: String
    public let city: String
    public let platonicAgreement: Bool

    enum CodingKeys: String, CodingKey {
        case id, goal, city
        case firstName = "first_name"
        case jobTitle = "job_title"
        case dateOfBirth = "date_of_birth"
        case platonicAgreement = "platonic_agreement"
    }

    // No verification status is writable through this client model.
    public init(id: UUID, draft: ProfileDraft, today: Date = .now) throws {
        try draft.validate(today: today)
        self.id = id
        firstName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        jobTitle = draft.jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        goal = draft.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        dateOfBirth = draft.dateOfBirth
        city = "Scottsdale"
        platonicAgreement = draft.platonicAgreement
    }
}

public struct ProfileDraft: Equatable, Sendable {
    public var firstName = ""
    public var jobTitle = ""
    public var goal = ""
    public var dateOfBirth = ""
    public var platonicAgreement = false

    public init() {}

    public init(profile: Profile) {
        firstName = profile.firstName
        jobTitle = profile.jobTitle
        goal = profile.goal
        dateOfBirth = profile.dateOfBirth
        platonicAgreement = profile.platonicAgreement
    }

    public func validate(today: Date = .now) throws {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let job = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(name.unicodeScalars.count) else { throw ProfileValidationError.firstName }
        guard (1...80).contains(job.unicodeScalars.count) else { throw ProfileValidationError.jobTitle }
        guard (10...280).contains(summary.unicodeScalars.count) else { throw ProfileValidationError.goal }
        guard let birthDate = BirthDate.parse(dateOfBirth),
              let minimumBirthday = BirthDate.calendar.date(byAdding: .year, value: 18, to: birthDate),
              minimumBirthday <= BirthDate.calendar.startOfDay(for: today)
        else { throw ProfileValidationError.age }
        guard platonicAgreement else { throw ProfileValidationError.agreement }
    }
}

public enum ProfileValidationError: Error, LocalizedError {
    case firstName, jobTitle, goal, age, agreement

    public var errorDescription: String? {
        switch self {
        case .firstName: "Enter a first name between 1 and 40 characters."
        case .jobTitle: "Enter a job title between 1 and 80 characters."
        case .goal: "Tell us what you’re up for in 10–280 characters."
        case .age: "Enter a valid birthday. You must be at least 18 to join."
        case .agreement: "Please agree to keep newtotown strictly platonic."
        }
    }
}

/// Birthdays are calendar dates, never local timestamps. UTC matches the database.
public enum BirthDate {
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    public static func parse(_ value: String) -> Date? {
        let formatter = formatter()
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }

    public static func string(from date: Date) -> String { formatter().string(from: date) }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}
