import Foundation

/// Public projection only: birthday, selfie, email, and moderation fields are excluded.
public struct DiscoveryProfile: Decodable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let firstName: String
    public let jobTitle: String
    public let goal: String
    public let city: String
    public let photoURL: URL

    public init(id: UUID, firstName: String, jobTitle: String, goal: String, city: String, photoURL: URL) {
        self.id = id
        self.firstName = firstName
        self.jobTitle = jobTitle
        self.goal = goal
        self.city = city
        self.photoURL = photoURL
    }
    enum CodingKeys: String, CodingKey {
        case id, goal, city
        case firstName = "first_name", jobTitle = "job_title", photoURL = "photo_url"
    }
}

public struct DiscoveryFeed: Decodable, Equatable, Sendable {
    public enum Status: String, Decodable, Sendable {
        case ready, hidden, restricted
        case needsProfile = "needs_profile", needsPhoto = "needs_photo", needsReview = "needs_review"
    }
    public let state: Status
    public let visible: Bool
    public let candidates: [DiscoveryProfile]
    public let matches: [DiscoveryProfile]

    public init(state: Status, visible: Bool, candidates: [DiscoveryProfile] = [], matches: [DiscoveryProfile] = []) {
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
