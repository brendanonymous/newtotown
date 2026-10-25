import Foundation
import Testing

@testable import NewToTownCore

@Test func singlePhotoServersRemainCompatibleAndThreePhotoGalleriesDecodeInOrder() throws {
    var object: [String: Any] = [
        "id": UUID().uuidString, "first_name": "Alex", "job_title": "Designer",
        "goal": "Coffee", "city": "Scottsdale", "photo_url": "https://test/photo1.jpg",
    ]
    func decode() throws -> DiscoveryProfile {
        try JSONDecoder().decode(DiscoveryProfile.self, from: JSONSerialization.data(withJSONObject: object))
    }
    #expect(try decode().photoURLs.map(\.absoluteString) == ["https://test/photo1.jpg"])
    object["photo_urls"] = ["https://test/photo1.jpg", "https://test/photo2.jpg", "https://test/photo3.jpg"]
    #expect(try decode().photoURLs.count == 3)
    for invalid in [[], ["https://test/photo2.jpg"], Array(repeating: "https://test/photo1.jpg", count: 4)] {
        object["photo_urls"] = invalid
        #expect(throws: DecodingError.self) { try decode() }
    }
}
