import SwiftUI
import UIKit

enum BrandTheme {
    static let textCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 16
    // Corrected pack: warm white #FBF8F4 and the sage gradient midpoint #B5BEA6.
    static let background = adaptive(light: 0xFBF8F4, dark: 0x1B251E)
    static let inputSurface = adaptive(light: 0xFFFFFF, dark: 0x293B30)
    static let sage = Color(red: 181 / 255, green: 190 / 255, blue: 166 / 255)
    static let ink = adaptive(light: 0x293B30, dark: 0xFBF8F4)
    static let secondaryInk = adaptive(light: 0x596653, dark: 0xBEC5AC)

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
