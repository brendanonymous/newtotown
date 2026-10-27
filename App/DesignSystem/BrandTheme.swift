import SwiftUI
import UIKit

enum BrandTheme {
    static let textCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 16
    // Ivory and sage follow the supplied asset pack; ink remains the legible action color.
    static let background = adaptive(light: 0xFAF5EF, dark: 0x1B251E)
    static let inputSurface = adaptive(light: 0xFFFFFF, dark: 0x293B30)
    static let sage = Color(red: 168 / 255, green: 173 / 255, blue: 143 / 255)
    static let ink = adaptive(light: 0x293B30, dark: 0xFAF5EF)
    static let secondaryInk = adaptive(light: 0x596653, dark: 0xB9BDA9)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(
            UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
            })
    }
}
