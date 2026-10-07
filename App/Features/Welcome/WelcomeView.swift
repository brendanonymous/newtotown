import NewToTownCore
import SwiftUI

struct WelcomeView: View {
    let onboardingModel: OnboardingModel?
    var photoService: (any PhotoService)? = nil

    @State private var showingSignup = false
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

                Label("SCOTTSDALE, AZ", systemImage: "mappin")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(BrandTheme.sage.opacity(0.22), in: Capsule())

                VStack(spacing: 16) {
                    Button {
                        showingSignup = true
                    } label: {
                        Text("Join or sign in")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .foregroundStyle(BrandTheme.background)
                            .background(BrandTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    }
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

                    Text("Pilot build · Scottsdale, Arizona")
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
        .sheet(isPresented: $showingSignup) { OnboardingView(model: onboardingModel, photoService: photoService) }
    }
}

#Preview {
    NavigationStack { WelcomeView(onboardingModel: nil) }
}
