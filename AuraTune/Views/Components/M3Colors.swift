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

/// Material Design 3 Style Colors (Aura Design System)
struct M3Colors {
    static let primary = Color(hex: "FF9E66")
    static let primaryDark = Color(hex: "994A1A") // Dark orange / brown for primary buttons
    static let secondary = Color(hex: "FFD966")
    static let tertiary = Color(hex: "8B5CF6")
    static let neutral = Color(hex: "1E1B4B") // Dark navy for text
    
    static let surface = Color(hex: "FDF8F5") // Very light tint of primary
    static let surfaceVariant = Color.white   // Cards are mostly white
    static let onSurface = Color(hex: "1E1B4B") // Neutral text
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
    static var auraOnSurface: Color { M3Colors.onSurface }
}
