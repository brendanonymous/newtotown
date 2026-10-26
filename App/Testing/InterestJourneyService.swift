#if DEBUG
    import NewToTownCore

    /// Account-local, persistent catalog fixture. Live options always come from the server.
    actor InterestJourneyService: InterestsService {
        private var profile: [String] = []
        private var filters: [String] = []
        private let categories: [InterestCategory] = [
            (
                "sports_fitness", "Sports & fitness",
                [
                    "Golf", "Pickleball", "Gun Range", "Gym", "Running", "Combat Sports", "Basketball",
                    "Tennis",
                ]
            ),
            ("outdoors", "Outdoors", ["Hiking", "Camping", "Cycling", "Fishing", "Kayaking", "Dog walks"]),
            (
                "food_drinks", "Food & drinks",
                ["Coffee", "Craft beer", "Dining out", "TSL's", "Cooking", "Barbecue", "Dive Bars", "Wine"]
            ),
            (
                "arts_entertainment", "Arts & entertainment",
                ["Live music", "Movies", "Comedy", "Museums", "Photography", "Theater"]
            ),
            (
                "social_hobbies", "Social & hobbies",
                [
                    "Chess", "Video games", "Volunteering", "Professional networking", "Reading",
                    "Cars", "DIY", "Mogging", "Poker", "Sports betting",
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

        func save(_ optionIDs: [String], for kind: InterestSelectionKind) -> InterestsSnapshot {
            if kind == .profile { profile = optionIDs } else { filters = optionIDs }
            return load()
        }
    }
#endif
