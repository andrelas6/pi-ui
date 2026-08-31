import Foundation

/// The transcript is CSS and the chrome is SwiftUI. Rather than keep two hand-written
/// copies of the palette, the `:root` block is generated from the Swift tokens — a
/// changed value moves both, and neither can quietly fall out of step with the other.
enum Stylesheet {
    static var rootVariables: String {
        var lines: [String] = [":root {"]

        lines.append("  --color-bg: \(Palette.bgHex);")
        lines.append("  --color-surface: \(Palette.surfaceHex);")
        lines.append("  --color-text: \(Palette.textHex);")
        lines.append("  --color-accent: \(Palette.accentHex);")
        lines.append("  --color-divider: color-mix(in srgb, \(Palette.textHex) 16%, transparent);")
        lines.append("  --color-ochre: \(Palette.ochreHex);")
        lines.append("  --color-ochre-text: \(Palette.ochreTextHex);")
        lines.append("  --color-removed: \(Palette.removedHex);")
        lines.append("  --color-removed-text: \(Palette.removedTextHex);")

        for (index, hex) in Palette.neutralHexes.enumerated() {
            lines.append("  --color-neutral-\((index + 1) * 100): \(hex);")
        }
        for (index, hex) in Palette.accentHexes.enumerated() {
            lines.append("  --color-accent-\((index + 1) * 100): \(hex);")
        }

        for (index, step) in Space.all.enumerated() {
            lines.append("  --space-\(scaleName(index)): \(trim(step))px;")
        }

        lines.append("  --font-heading: \"\(Typeface.headingFamily)\", system-ui, sans-serif;")
        lines.append("  --font-body: \"\(Typeface.bodyFamily)\", system-ui, sans-serif;")
        lines.append("  --font-mono: \(Typeface.monoStack);")
        lines.append("  --log-max-width: \(trim(Frame.logMaximum))px;")

        lines.append("  --shadow-sm: 0 1px 2px color-mix(in srgb, \(Palette.neutralHexes[8]) 14%, transparent);")
        lines.append("  --shadow-md: 0 3px 10px color-mix(in srgb, \(Palette.neutralHexes[8]) 16%, transparent);")
        lines.append("  --shadow-lg: 0 12px 32px color-mix(in srgb, \(Palette.neutralHexes[8]) 22%, transparent);")

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// The stylesheet names steps 1,2,3,4,6,8 — the scale skips 5 and 7.
    private static func scaleName(_ index: Int) -> Int {
        [1, 2, 3, 4, 6, 8][index]
    }

    private static func trim(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
