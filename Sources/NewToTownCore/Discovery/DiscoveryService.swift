import Foundation

/// Public projection only: birthday, selfie, email, and moderation fields are excluded.
public struct DiscoveryProfile: Decodable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let firstName: String
    public let jobTitle: String
    public let goal: String
    public let city: String
    public let photoURL: URL
    public let interests: [ProfileInterest]

    public init(
        id: UUID, firstName: String, jobTitle: String, goal: String, city: String, photoURL: URL,
        interests: [ProfileInterest] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.jobTitle = jobTitle
        self.goal = goal
        self.city = city
        self.photoURL = photoURL
        self.interests = interests
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(UUID.self, forKey: .id),
            firstName: try values.decode(String.self, forKey: .firstName),
            jobTitle: try values.decode(String.self, forKey: .jobTitle),
            goal: try values.decode(String.self, forKey: .goal),
            city: try values.decode(String.self, forKey: .city),
            photoURL: try values.decode(URL.self, forKey: .photoURL),
            interests: try values.decodeIfPresent([ProfileInterest].self, forKey: .interests) ?? [])
    }
    enum CodingKeys: String, CodingKey {
        case id, goal, city, interests
        case firstName = "first_name"
        case jobTitle = "job_title"
        case photoURL = "photo_url"
    }
}

public struct DiscoveryFeed: Decodable, Equatable, Sendable {
    public enum Status: String, Decodable, Sendable {
        case ready, hidden, restricted
        case needsProfile = "needs_profile"
        case needsPhoto = "needs_photo"
        case needsReview = "needs_review"
    }
    public let state: Status
    public let visible: Bool
    public let candidates: [DiscoveryProfile]
    public let matches: [DiscoveryProfile]

    public init(
        state: Status, visible: Bool, candidates: [DiscoveryProfile] = [], matches: [DiscoveryProfile] = []
    ) {
        self.state = state
        self.visible = visible
        self.candidates = candidates
        self.matches = matches
    }
}

public enum ConnectionChoice: String, Sendable { case connect, pass }

public protocol DiscoveryService: Sendable {
    func load() async throws -> DiscoveryFeed
    func setVisible(_ visible: Bool) async throws -> DiscoveryFeed
    func decide(on profileID: UUID, choice: ConnectionChoice) async throws -> DiscoveryFeed
    func block(_ profileID: UUID) async throws -> DiscoveryFeed
}
