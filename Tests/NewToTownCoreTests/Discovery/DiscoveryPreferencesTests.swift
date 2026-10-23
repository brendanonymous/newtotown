import Foundation
import Testing

@testable import NewToTownCore

@Test func agePreferencesValidateInclusiveBoundsAndDecodeDefaults() throws {
    #expect(AgePreferences().isValid)
    #expect(AgePreferences(minimumAge: 30, maximumAge: 30).isValid)
    #expect(!AgePreferences(minimumAge: 17).isValid)
    #expect(!AgePreferences(minimumAge: 30, maximumAge: 29).isValid)
    #expect(!AgePreferences(minimumAge: Int.max).isValid)
    let data = Data(#"{"minimum_age":18,"maximum_age":null}"#.utf8)
    #expect(try JSONDecoder().decode(AgePreferences.self, from: data) == AgePreferences())
}
