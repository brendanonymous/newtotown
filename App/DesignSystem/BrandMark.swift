import SwiftUI

/// Typographic stand-in until the final monogram asset is supplied.
struct BrandMark: View {
    var body: some View {
        Text("N")
            .font(.system(size: 80, weight: .medium, design: .serif))
            .foregroundStyle(BrandTheme.background)
            .frame(width: 116, height: 116)
            .background(BrandTheme.sage.gradient, in: RoundedRectangle(cornerRadius: 30))
            .overlay {
                RoundedRectangle(cornerRadius: 30)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: BrandTheme.ink.opacity(0.12), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}
