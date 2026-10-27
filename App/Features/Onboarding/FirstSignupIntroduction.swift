import SwiftUI

/// Appears only until the authenticated account has a recorded acceptance.
struct FirstSignupIntroduction: View {
    let isBusy: Bool
    let accept: @MainActor () async -> Void
    @State private var page = 0
    @ScaledMetric(relativeTo: .body) private var slideHeight: CGFloat = 340

    private let slides: [(symbol: String, title: String, message: String)] = [
        ("person.2", "Friends. Simply.", "NewToTown is for platonic friendship.\nNo dating or sexual solicitation."),
        ("hand.raised", "Keep it respectful.", "Good friendships start with kindness. \nTreat others with respect, and report behavior that crosses the line."),
        ("lock", "Your profile on your terms.", "When you join Discovery, others can see your name, job, bio, interests, and photos. \nYou're always in control. Remove photos or hide your profile whenever you want.")
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
                
                Button("I agree") { Task { await accept() } }
                    .accessibilityIdentifier("signup.acceptAgreement")
                    .buttonStyle(BrandActionButtonStyle())
                    .foregroundStyle(BrandTheme.background)
            } else {
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(BrandActionButtonStyle())
                    .foregroundStyle(BrandTheme.background)
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
}
