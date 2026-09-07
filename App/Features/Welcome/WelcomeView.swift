import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                Text("NEWTOTOWN")
                    .font(.caption.weight(.semibold))
                    .tracking(4)
                    .padding(.top, 24)

                BrandMark()
                    .padding(.top, 28)

                VStack(spacing: 20) {
                    Text("Good company.\nNew beginnings.")
                        .font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center)

                    Text("Meet local guys. Make actual friends.")
                        .font(.body)
                        .foregroundStyle(BrandTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                }

                Label("SCOTTSDALE, AZ · 18+", systemImage: "mappin")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(BrandTheme.sage.opacity(0.22), in: Capsule())

                VStack(spacing: 16) {
                    NavigationLink {
                        PilotOverviewView()
                    } label: {
                        HStack {
                            Text("About the Scottsdale pilot")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.body.weight(.medium))
                        .padding(20)
                        .foregroundStyle(BrandTheme.background)
                        .background(BrandTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    }

                    Text("Preview build · Signup is coming next")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.secondaryInk)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
