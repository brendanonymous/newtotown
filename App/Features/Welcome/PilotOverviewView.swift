import SwiftUI

struct PilotOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("A familiar face.\nA new friend.")
                    .font(.system(.largeTitle, design: .serif))

                Text("We’re building a place for men in Scottsdale to find platonic friendship, one real-world plan at a time.")
                    .foregroundStyle(BrandTheme.secondaryInk)

                detail("Show up as yourself", symbol: "person.crop.rectangle", description: "Share your job, a photo, and what you’d like to do. The pilot will include manual photo review.")
                detail("Find common ground", symbol: "checkmark", description: "Connect or pass. When you both connect, you’ll be able to start a conversation.")
                detail("Make a plan", symbol: "cup.and.saucer", description: "Coffee, a hike, or a beer in Old Town. Keep it simple, local, and strictly platonic.")

                Text("This pilot build supports email signup and private profile details. Photo verification, discovery, and messaging are coming next.")
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.secondaryInk)
                    .padding(20)
                    .background(BrandTheme.sage.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
        .navigationTitle("The pilot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ title: String, symbol: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            Text(description)
                .foregroundStyle(BrandTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
