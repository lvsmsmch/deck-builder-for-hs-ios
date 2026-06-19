import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppColor {
    static let surface = Color(light: 0xF8F8FB, dark: 0x0B0B0E)
    static let surfaceContainer = Color(light: 0xFFFFFF, dark: 0x15161B)
    static let surfaceContainerHigh = Color(light: 0xECEEF4, dark: 0x1E1F26)
    static let surfaceContainerHighest = Color(light: 0xE0E3EC, dark: 0x262830)
    static let outline = Color(light: 0xD1D5E0, dark: 0x2A2C34)
    static let outlineSoft = Color(light: 0xE1E4EC, dark: 0x23252C)
    static let onSurface = Color(light: 0x15161B, dark: 0xECEDEF)
    static let onSurfaceDim = Color(light: 0x616977, dark: 0xA7ADB4)
    static let onSurfaceDimmer = Color(light: 0x8A92A0, dark: 0x747B84)
    static let primary = Color(light: 0x5367E8, dark: 0x7C8CFF)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let primarySoft = Color(light: 0x5367E8, dark: 0x7C8CFF, lightAlpha: 0.14, darkAlpha: 0.13)
    static let secondary = Color(light: 0xA05D00, dark: 0xFFB454)
    static let error = Color(light: 0xC93333, dark: 0xFF6E6E)
    static let success = Color(light: 0x1F8A55, dark: 0x5CC58A)

    static func classColor(_ slug: String?) -> Color {
        switch slug?.normalizedClassSlug {
        case "druid": Color(hex: 0x9C7B4F)
        case "hunter": Color(hex: 0x5A6E3F)
        case "mage": Color(hex: 0x3F6CB5)
        case "paladin": Color(hex: 0xC9A24C)
        case "priest": Color(hex: 0xD6D6D6)
        case "rogue": Color(hex: 0x7A7A7A)
        case "shaman": Color(hex: 0x4A6C9D)
        case "warlock": Color(hex: 0x7E5BA8)
        case "warrior": Color(hex: 0xA05A45)
        case "demonhunter": Color(hex: 0x5C8E3D)
        case "deathknight": Color(hex: 0x9E5C5C)
        default: Color(hex: 0x7A7A7A)
        }
    }

    static func rarityColor(_ slug: String?) -> Color {
        switch slug?.lowercased() {
        case "rare": Color(hex: 0x5BA6FF)
        case "epic": Color(hex: 0xB176FF)
        case "legendary": Color(hex: 0xFFC857)
        default: Color(hex: 0xB7BBC2)
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init(light: UInt, dark: UInt, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        #if canImport(UIKit)
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
            return UIColor(hex: hex, alpha: alpha)
        })
        #else
        self.init(hex: dark, alpha: darkAlpha)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#endif

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.surface.ignoresSafeArea())
            .tint(AppColor.primary)
            .foregroundStyle(AppColor.onSurface)
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackground())
    }

    func compactCard(cornerRadius: CGFloat = 8) -> some View {
        background(AppColor.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColor.outlineSoft, lineWidth: 1)
            )
    }
}
