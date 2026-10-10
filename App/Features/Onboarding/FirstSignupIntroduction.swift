import SwiftUI

/// Appears only until the authenticated account has a recorded acceptance.
struct FirstSignupIntroduction: View {
    let isBusy: Bool
    let accept: @MainActor () async -> Void
    @State private var page = 0
    @ScaledMetric(relativeTo: .body) private var slideHeight: CGFloat = 340

    private let slides: [(symbol: String, title: String, message: String)] = [
        ("person.2", "Friends. Simply.", "newtotown is for platonic friendship. No dating or sexual solicitation."),
        ("hand.raised", "Keep it respectful.", "Treat people with care. No harassment. You can block anyone and delete your account at any time."),
        ("lock", "Your profile. Your choice.", "We store your account details and photos. Your birthday and any review selfie stay private. Joining discovery shares your first name, job, activity summary, and profile photo. You can hide your profile or remove your photos at any time.")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: slides[index].symbol)
                            .font(.system(size: 42, weight: .light))
                            .accessibilityHidden(true)
                        Text(slides[index].title)
                            .font(.system(.largeTitle, design: .serif))
                        Text(slides[index].message)
                            .foregroundStyle(BrandTheme.secondaryInk)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: slideHeight)
            .disabled(isBusy)
            HStack(spacing: 8) {
                ForEach(slides.indices, id: \.self) { index in
                    Circle().fill(index == page ? BrandTheme.ink : BrandTheme.sage)
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Introduction page \(page + 1) of \(slides.count)")
            if page == slides.count - 1 {
                Text("By tapping below, I agree to the storage and safety terms above, confirm I’m at least 18 years old, and commit to using newtotown only for platonic friendship.")
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                Button("I agree — keep it platonic") { Task { await accept() } }
                    .accessibilityIdentifier("signup.acceptAgreement")
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(BrandTheme.background)
            } else {
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(BrandTheme.background)
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
}
