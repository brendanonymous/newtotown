import Foundation

public struct InterestOption: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct InterestCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let options: [InterestOption]
    public init(id: String, title: String, options: [InterestOption]) {
        self.id = id
        self.title = title
        self.options = options
    }
}

/// Safe public fields; Discovery filters never belong on somebody else's profile.
public struct ProfileInterest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let categoryID: String
    public let title: String
    public init(id: String, categoryID: String, title: String) {
        self.id = id
        self.categoryID = categoryID
        self.title = title
    }
    enum CodingKeys: String, CodingKey {
        case id, title
        case categoryID = "category_id"
    }
}

public enum InterestSelectionKind: String, Sendable { case profile, filters }

public struct InterestsSnapshot: Codable, Equatable, Sendable {
    public let categories: [InterestCategory]
    public let profileOptionIDs: [String]
    public let filterOptionIDs: [String]
    public init(categories: [InterestCategory], profileOptionIDs: [String], filterOptionIDs: [String]) {
        self.categories = categories
        self.profileOptionIDs = profileOptionIDs
        self.filterOptionIDs = filterOptionIDs
    }
    enum CodingKeys: String, CodingKey {
        case categories
        case profileOptionIDs = "profile_option_ids"
        case filterOptionIDs = "filter_option_ids"
    }
    public func selection(for kind: InterestSelectionKind) -> [String] {
        kind == .profile ? profileOptionIDs : filterOptionIDs
    }
    public var profileInterests: [ProfileInterest] {
        categories.flatMap { category in
            category.options.filter { profileOptionIDs.contains($0.id) }.map {
                ProfileInterest(id: $0.id, categoryID: category.id, title: $0.title)
            }
        }
    }
    public var isValid: Bool {
        guard categories.count == 5, Set(categories.map(\.id)).count == categories.count else { return false }
        var options: Set<String> = []
        for category in categories {
            guard validInterestID(category.id), validTitle(category.title), category.options.count <= 100
            else { return false }
            for option in category.options {
                guard validInterestID(option.id), validTitle(option.title), options.insert(option.id).inserted
                else { return false }
            }
        }
        return isValidSelection(Set(profileOptionIDs))
            && Set(profileOptionIDs).count == profileOptionIDs.count
            && isValidSelection(Set(filterOptionIDs)) && Set(filterOptionIDs).count == filterOptionIDs.count
    }
    public func isValidSelection(_ ids: Set<String>) -> Bool {
        let known = Set(categories.flatMap(\.options).map(\.id))
        return ids.count <= 15 && ids.isSubset(of: known)
            && categories.allSatisfy { category in category.options.filter { ids.contains($0.id) }.count <= 3
            }
    }
}

private func validInterestID(_ value: String) -> Bool {
    value.range(of: #"^[a-z][a-z0-9_]{0,63}$"#, options: .regularExpression) != nil
}
private func validTitle(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 80
}

public enum InterestsError: Error, Equatable, Sendable { case signedOut, invalidSelection, connection }
public protocol InterestsService: Sendable {
    func load() async throws -> InterestsSnapshot
    func save(_ optionIDs: [String], for kind: InterestSelectionKind) async throws -> InterestsSnapshot
}
