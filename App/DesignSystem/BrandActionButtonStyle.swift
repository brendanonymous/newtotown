import SwiftUI

/// Compact action buttons share one shape, including disabled and pressed states.
/// Native navigation, menu, and photo controls retain their platform behavior.
struct BrandActionButtonStyle: ButtonStyle {
    enum Tone { case primary, secondary }
    var tone: Tone = .primary
    var expands = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: 44)
            .foregroundStyle(tone == .primary ? BrandTheme.background : BrandTheme.ink)
            .background(
                tone == .primary ? BrandTheme.ink : BrandTheme.sage.opacity(0.18),
                in: RoundedRectangle(cornerRadius: BrandTheme.buttonCornerRadius, style: .continuous)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
