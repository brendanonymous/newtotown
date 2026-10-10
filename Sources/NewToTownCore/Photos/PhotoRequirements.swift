/// Server-controlled photo requirements. Unknown requirements must block uploads.
public struct PhotoRequirements: Equatable, Sendable {
    public let reviewRequired: Bool

    public init(reviewRequired: Bool) {
        self.reviewRequired = reviewRequired
    }
}
