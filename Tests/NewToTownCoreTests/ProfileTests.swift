import Foundation
import Testing
@testable import NewToTownCore

private let today = BirthDate.parse("2026-09-07")!

func validDraft() -> ProfileDraft {
    var draft = ProfileDraft()
    draft.firstName = " Alex "
    draft.jobTitle = " Designer "
    draft.goal = " Find a hiking buddy. "
    draft.dateOfBirth = "1990-01-01"
    draft.platonicAgreement = true
    return draft
}

@Test func permitsEighteenthBirthday() throws {
    var draft = validDraft()
    draft.dateOfBirth = "2008-09-07"
    try draft.validate(today: today)
}

@Test(arguments: ["2008-09-08", "2027-01-01", "2008-02-30", "", "2008-9-7"])
func rejectsUnderageOrMalformedBirthday(_ birthday: String) {
    var draft = validDraft()
    draft.dateOfBirth = birthday
    #expect(throws: ProfileValidationError.self) { try draft.validate(today: today) }
}

@Test func validatesLeapDayBirthday() throws {
    var draft = validDraft()
    draft.dateOfBirth = "2008-02-29"
    #expect(throws: ProfileValidationError.self) { try draft.validate(today: BirthDate.parse("2026-02-27")!) }
    try draft.validate(today: BirthDate.parse("2026-03-01")!)
}

@Test func rejectsMissingAgreementAndEmptySummary() {
    var draft = validDraft()
    draft.platonicAgreement = false
    #expect(throws: ProfileValidationError.self) { try draft.validate(today: today) }
    draft.platonicAgreement = true
    draft.goal = "   "
    #expect(throws: ProfileValidationError.self) { try draft.validate(today: today) }
}

@Test func normalizesFieldsAndNeverEncodesApproval() throws {
    let profile = try Profile(id: UUID(), draft: validDraft(), today: today)
    #expect(profile.firstName == "Alex")
    #expect(profile.jobTitle == "Designer")
    #expect(profile.city == "Scottsdale")
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
    #expect(json["verification_status"] == nil)
    #expect(json["date_of_birth"] as? String == "1990-01-01")
}
