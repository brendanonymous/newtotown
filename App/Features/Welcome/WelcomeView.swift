import NewToTownCore
import SwiftUI

struct WelcomeView: View {
    let onJoin: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                BrandMark()
                    .padding(.top, 28)

                VStack(spacing: 20) {
                    Text("Good company.\nNew beginnings.")
                        .font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center)

                    Text("Meet local friends.")
                        .font(.body)
                        .foregroundStyle(BrandTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                }

                Label("SCOTTSDALE, AZ", systemImage: "mappin")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(BrandTheme.sage.opacity(0.22), in: Capsule())

                VStack(spacing: 16) {
                    Button {
                        onJoin?()
                    } label: {
                        Text("Join or sign in")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .foregroundStyle(BrandTheme.background)
                            .background(BrandTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(onJoin == nil)
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
                        .foregroundStyle(BrandTheme.ink)
                        .background(BrandTheme.sage.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
                    }

                    Text("Scottsdale, Arizona")
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
        .toolbar { BrandNavigationLogo() }
    }
}

#Preview {
    NavigationStack { WelcomeView(onJoin: {}) }
}
