import NewToTownCore
import SwiftUI

struct DiscoveryProfileCard: View {
    let profile: DiscoveryProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AsyncImage(url: profile.photoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    Label("Photo unavailable. Refresh to try again.", systemImage: "photo")
                        .font(.callout).padding()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(BrandTheme.sage.opacity(0.22))
            .clipped()
            .brandPhotoStyle()
            Text(profile.firstName).font(.system(.title, design: .serif))
            Text(profile.jobTitle).font(.headline)
            Text(profile.goal)
            Label(profile.city, systemImage: "mappin").font(.footnote)
                .foregroundStyle(BrandTheme.secondaryInk)
        }
    }
}
