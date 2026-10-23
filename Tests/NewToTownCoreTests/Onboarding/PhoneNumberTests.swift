import Testing

@testable import NewToTownCore

@Test(arguments: ["4805550142", "(480) 555-0142", "1 480 555 0142", "+1 (480) 555-0142"])
func phoneNormalizesUSNumbers(_ input: String) {
    #expect(PhoneNumber(rawValue: input)?.rawValue == "+14805550142")
}

@Test func phonePreservesExplicitInternationalCode() {
    #expect(PhoneNumber(rawValue: "+44 20 7946 0958")?.rawValue == "+442079460958")
}

@Test(arguments: [
    "", "480", "480-CALL-NOW", "4805550142 ext 1", "++14805550142", "+014805550142", "+1234567890123456",
    "４８０５５５０１４２", "480\n5550142",
])
func phoneRejectsAmbiguousOrUnsupportedInput(_ input: String) {
    #expect(PhoneNumber(rawValue: input) == nil)
}
