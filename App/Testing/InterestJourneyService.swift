#if DEBUG
    import NewToTownCore

    /// Account-local, persistent catalog fixture. Live options always come from the server.
    actor InterestJourneyService: InterestsService {
        private var profile: [String] = []
        private var filters: [String] = []
        private let categories: [InterestCategory] = [
            (
                "sports_fitness", "Sports & fitness",
                ["Golf", "Pickleball", "Gym", "Running", "Basketball", "Tennis"]
            ),
            ("outdoors", "Outdoors", ["Hiking", "Camping", "Cycling", "Fishing", "Kayaking", "Dog walks"]),
            (
                "food_drinks", "Food & drinks",
                ["Coffee", "Craft beer", "Dining out", "Cooking", "Barbecue", "Wine"]
            ),
            (
                "arts_entertainment", "Arts & entertainment",
                ["Live music", "Movies", "Comedy", "Museums", "Photography", "Theater"]
            ),
            (
                "social_hobbies", "Social & hobbies",
                ["Board games", "Video games", "Volunteering", "Professional networking", "Reading", "Cars"]
            ),
        ].map { id, title, options in
            InterestCategory(
                id: id, title: title,
                options: options.map {
                    InterestOption(id: $0.lowercased().replacingOccurrences(of: " ", with: "_"), title: $0)
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
