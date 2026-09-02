import Foundation

/// The transcript is CSS and the chrome is SwiftUI. Rather than keep two hand-written
/// copies of the palette, the `:root` block is generated from the Swift tokens — a
/// changed value moves both, and neither can quietly fall out of step with the other.
///
/// Both themes ship in the one document behind a media query, so the transcript follows
/// the appearance without being rebuilt or reloaded.
enum Stylesheet {
    static var rootVariables: String {
        let light = """
        :root {
        \(colors(Theme.light))
        \(metrics())
        }
        """

        let dark = """
        @media (prefers-color-scheme: dark) {
          :root {
        \(colors(Theme.dark, indent: "    "))
          }
        }
        """

        return light + "\n" + dark
    }

    /// Everything that changes with the appearance. Both themes go through here, so a
    /// token cannot exist in one block and be missing from the other.
    private static func colors(_ theme: Theme, indent: String = "  ") -> String {
        var lines: [String] = []

        lines.append("--color-bg: \(theme.bg);")
        lines.append("--color-surface: \(theme.surface);")
        lines.append("--color-text: \(theme.text);")
        lines.append("--color-accent: \(theme.accent);")
        lines.append("--color-on-accent: \(theme.onAccent);")
        lines.append("--color-divider: color-mix(in srgb, \(theme.text) 16%, transparent);")
        lines.append("--color-ochre: \(theme.ochre);")
        lines.append("--color-ochre-text: \(theme.ochreText);")
        lines.append("--color-removed: \(theme.removed);")
        lines.append("--color-removed-text: \(theme.removedText);")

        for (index, hex) in theme.neutrals.enumerated() {
            lines.append("--color-neutral-\((index + 1) * 100): \(hex);")
        }
        for (index, hex) in theme.accents.enumerated() {
            lines.append("--color-accent-\((index + 1) * 100): \(hex);")
        }

        lines.append("--shadow-sm: 0 1px 2px color-mix(in srgb, \(theme.shadow) 14%, transparent);")
        lines.append("--shadow-md: 0 3px 10px color-mix(in srgb, \(theme.shadow) 16%, transparent);")
        lines.append("--shadow-lg: 0 12px 32px color-mix(in srgb, \(theme.shadow) 22%, transparent);")

        return lines.map { indent + $0 }.joined(separator: "\n")
    }

    /// Type and spacing do not vary by appearance, so they are written once.
    private static func metrics(indent: String = "  ") -> String {
        var lines: [String] = []

        for (index, step) in Space.all.enumerated() {
            lines.append("--space-\(scaleName(index)): \(trim(step))px;")
        }

        lines.append("--font-heading: \"\(Typeface.headingFamily)\", system-ui, sans-serif;")
        lines.append("--font-body: \"\(Typeface.bodyFamily)\", system-ui, sans-serif;")
        lines.append("--font-mono: \(Typeface.monoStack);")
        lines.append("--log-max-width: \(trim(Frame.logMaximum))px;")

        return lines.map { indent + $0 }.joined(separator: "\n")
    }

    /// The stylesheet names steps 1,2,3,4,6,8 — the scale skips 5 and 7.
    private static func scaleName(_ index: Int) -> Int {
        [1, 2, 3, 4, 6, 8][index]
    }

    private static func trim(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
