import SwiftUI

enum AppColor {
    static let surface = Color(hex: 0x0B0B0E)
    static let surfaceContainer = Color(hex: 0x15161B)
    static let surfaceContainerHigh = Color(hex: 0x1E1F26)
    static let surfaceContainerHighest = Color(hex: 0x262830)
    static let outline = Color(hex: 0x2A2C34)
    static let outlineSoft = Color(hex: 0x23252C)
    static let onSurface = Color(hex: 0xECEDEF)
    static let onSurfaceDim = Color(hex: 0x9AA0A6)
    static let onSurfaceDimmer = Color(hex: 0x6B7178)
    static let primary = Color(hex: 0x7C8CFF)
    static let onPrimary = Color(hex: 0x0B0B0E)
    static let primarySoft = Color(hex: 0x7C8CFF, alpha: 0.13)
    static let secondary = Color(hex: 0xFFB454)
    static let error = Color(hex: 0xFF6E6E)
    static let success = Color(hex: 0x5CC58A)

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
}

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
