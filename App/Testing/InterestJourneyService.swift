#if DEBUG
    import Foundation
    import NewToTownCore

    /// Account-local, persistent catalog fixture. Live options always come from the server.
    actor InterestJourneyService: InterestsService {
        private var profile: [String] = []
        private var filters: [String] = []
        private var failedSave = false
        private let categories: [InterestCategory] = [
            (
                "sports_fitness", "Sports & fitness",
                [
                    "Golf", "Pickleball", "Gun Range", "Gym", "Running", "Combat Sports", "Basketball",
                    "Tennis", "Soccer", "Baseball", "Swimming", "Yoga", "Volleyball",
                ]
            ),
            (
                "outdoors", "Outdoors",
                [
                    "Hiking", "Camping", "Cycling", "Fishing", "Kayaking", "Dog walks", "Trail running",
                    "Rock climbing", "Paddleboarding", "Skiing", "Backpacking",
                ]
            ),
            (
                "food_drinks", "Food & drinks",
                [
                    "Coffee", "Craft beer", "Dining out", "TSL's", "Cooking", "Barbecue", "Dive Bars", "Wine",
                    "Brunch", "Food trucks", "Sushi", "Pizza", "Baking",
                ]
            ),
            (
                "arts_entertainment", "Arts & entertainment",
                [
                    "Live music", "Movies", "Comedy", "Museums", "Photography", "Theater", "Festivals",
                    "Art galleries", "Podcasts", "Painting", "Dancing",
                ]
            ),
            (
                "social_hobbies", "Social & hobbies",
                [
                    "Chess", "Video games", "Volunteering", "Professional networking", "Reading",
                    "Cars", "DIY", "Mogging", "Poker", "Sports betting", "Trivia", "Travel",
                    "Language exchange", "Entrepreneurship", "Personal finance",
                ]
            ),
        ].map { id, title, options in
            InterestCategory(
                id: id, title: title,
                options: options.map {
                    InterestOption(
                        id: $0.lowercased().replacingOccurrences(of: " ", with: "_")
                            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression),
                        title: $0)
                })
        }

        func load() -> InterestsSnapshot {
            InterestsSnapshot(categories: categories, profileOptionIDs: profile, filterOptionIDs: filters)
        }

        func save(_ optionIDs: [String], for kind: InterestSelectionKind) throws -> InterestsSnapshot {
            if !failedSave && ProcessInfo.processInfo.arguments.contains("--ui-test-interest-save-fails") {
                failedSave = true
                throw InterestsError.connection
            }
            if kind == .profile { profile = optionIDs } else { filters = optionIDs }
            return load()
        }
    }
#endif
