import SwiftUI

/// Shared appearance for single-line and expanding text inputs.
struct BrandTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(12)
            .background(
                BrandTheme.inputSurface.opacity(0.65),
                in: RoundedRectangle(cornerRadius: BrandTheme.textCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BrandTheme.textCornerRadius)
                    .strokeBorder(BrandTheme.sage.opacity(0.7), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
