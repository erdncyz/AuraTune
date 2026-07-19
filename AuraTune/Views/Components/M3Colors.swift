import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// AuraTune's shared visual language.
struct M3Colors {
    static let primary = Color(hex: "C44F35")
    static let primaryDark = Color(hex: "8E3522")
    static let secondary = Color(hex: "D5A33F")
    static let tertiary = Color(hex: "2F7773")
    static let neutral = Color(hex: "1C2027")

    static let surface = Color(hex: "F5F3F0")
    static let surfaceVariant = Color(hex: "FCFBF9")
    static let surfaceElevated = Color.white
    static let onSurface = Color(hex: "1C2027")
    static let onSurfaceSecondary = Color(hex: "666970")
    static let outline = Color(hex: "DDD9D4")
    static let deepAccent = Color(hex: "252A33")

    static let success = Color(hex: "2F7655")
    static let warning = Color(hex: "A96B18")
    static let danger = Color(hex: "B6423C")
}

enum AuraMetrics {
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardPadding: CGFloat = 18
    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 12
    static let minimumTapTarget: CGFloat = 44
    static let contentMaxWidth: CGFloat = 760
}

/// Helper extension for easy theme access
extension Color {
    static var auraPrimary: Color { M3Colors.primary }
    static var auraPrimaryDark: Color { M3Colors.primaryDark }
    static var auraSecondary: Color { M3Colors.secondary }
    static var auraTertiary: Color { M3Colors.tertiary }
    static var auraNeutral: Color { M3Colors.neutral }
    
    static var auraSurface: Color { M3Colors.surface }
    static var auraSurfaceVariant: Color { M3Colors.surfaceVariant }
    static var auraSurfaceElevated: Color { M3Colors.surfaceElevated }
    static var auraOnSurface: Color { M3Colors.onSurface }
    static var auraTextSecondary: Color { M3Colors.onSurfaceSecondary }
    static var auraOutline: Color { M3Colors.outline }
    static var auraDeepAccent: Color { M3Colors.deepAccent }

    static var auraSuccess: Color { M3Colors.success }
    static var auraWarning: Color { M3Colors.warning }
    static var auraDanger: Color { M3Colors.danger }
}
