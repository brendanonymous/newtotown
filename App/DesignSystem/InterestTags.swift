import NewToTownCore
import SwiftUI

struct InterestTags: View {
    let interests: [ProfileInterest]
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 105), alignment: .leading)], alignment: .leading, spacing: 8
        ) {
            ForEach(interests) { interest in
                Text(interest.title).font(.caption).padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandTheme.sage.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .accessibilityLabel("Interests")
    }
}
