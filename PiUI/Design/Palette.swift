import SwiftUI

/// The Industry design system's colours. Hex strings are the source of truth: SwiftUI
/// reads them and the transcript's CSS is generated from the same values, so the chrome
/// and the message log cannot drift apart.
enum Palette {
    static let bgHex = "#f2f2f3"
    static let surfaceHex = "#e9e9ea"
    static let textHex = "#1d1f20"
    static let accentHex = "#5980a6"

    /// The one deliberate step outside the steel palette, for "needs input".
    static let ochreHex = "#b07d2e"
    static let ochreTextHex = "#7d5719"

    static let neutralHexes = [
        "#f5f5f8", "#e7e7ea", "#d4d4d7", "#b7b7ba", "#98989b",
        "#7a7a7d", "#5d5d60", "#424244", "#2b2b2d",
    ]

    static let accentHexes = [
        "#eef6ff", "#d6ebff", "#b5d9fd", "#94bce3", "#749dc4",
        "#597ea3", "#416180", "#2c455d", "#1d2d3d",
    ]

    static var bg: Color { Color(hex: bgHex) }
    static var surface: Color { Color(hex: surfaceHex) }
    static var text: Color { Color(hex: textHex) }
    static var accent: Color { Color(hex: accentHex) }
    static var ochre: Color { Color(hex: ochreHex) }
    static var ochreText: Color { Color(hex: ochreTextHex) }

    /// The divider is the text colour at 16%, not its own hex.
    static var divider: Color { text.opacity(0.16) }

    /// Steps run 100 to 900, as they do in the stylesheet.
    static func neutral(_ step: Int) -> Color {
        Color(hex: hex(neutralHexes, step))
    }

    static func accent(_ step: Int) -> Color {
        Color(hex: hex(accentHexes, step))
    }

    static func neutralHex(_ step: Int) -> String { hex(neutralHexes, step) }
    static func accentHex(_ step: Int) -> String { hex(accentHexes, step) }

    private static func hex(_ ramp: [String], _ step: Int) -> String {
        let index = (step / 100) - 1
        return ramp[min(max(index, 0), ramp.count - 1)]
    }
}

extension Color {
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
