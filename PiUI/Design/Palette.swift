import AppKit
import SwiftUI

/// One complete set of the Industry design system's colours. Hex strings are the source
/// of truth: SwiftUI reads them and the transcript's CSS is generated from the same
/// values, so the chrome and the message log cannot drift apart.
struct Theme {
    let bg: String
    let surface: String
    let text: String
    let accent: String

    /// The label inside a filled accent button. Not a ramp step, because the ramp flips
    /// direction between the two themes and this has to stay legible on the fill.
    let onAccent: String

    /// The one deliberate step outside the steel palette, for "needs input".
    let ochre: String
    let ochreText: String

    /// Removed lines in a diff. A second step outside the palette, kept dusty rather
    /// than a live red so it reads as a mark on the page, not an alarm.
    let removed: String
    let removedText: String

    /// What shadows are mixed from. Dark grounds need a black to sink into; reusing the
    /// last neutral would tint them light and read as a glow.
    let shadow: String

    /// Steps 100 to 900. Low steps are always the quiet surface and high steps the
    /// strong text, so the light ramp runs pale to dark and the dark ramp runs the
    /// other way. Every call site keeps its meaning across both.
    let neutrals: [String]
    let accents: [String]

    static let light = Theme(
        bg: "#f2f2f3",
        surface: "#e9e9ea",
        text: "#1d1f20",
        accent: "#5980a6",
        onAccent: "#f5f5f8",
        ochre: "#b07d2e",
        ochreText: "#7d5719",
        removed: "#f5dbd6",
        removedText: "#5f2d27",
        shadow: "#2b2b2d",
        neutrals: [
            "#f5f5f8", "#e7e7ea", "#d4d4d7", "#b7b7ba", "#98989b",
            "#7a7a7d", "#5d5d60", "#424244", "#2b2b2d",
        ],
        accents: [
            "#eef6ff", "#d6ebff", "#b5d9fd", "#94bce3", "#749dc4",
            "#597ea3", "#416180", "#2c455d", "#1d2d3d",
        ]
    )

    static let dark = Theme(
        bg: "#151617",
        surface: "#1c1d1f",
        text: "#e8e8ea",
        accent: "#7ea6cc",
        onAccent: "#12181e",
        ochre: "#d9a441",
        ochreText: "#e8c07d",
        removed: "#40211d",
        removedText: "#f0b8ae",
        shadow: "#000000",
        neutrals: [
            "#1e1f21", "#26282a", "#313335", "#3f4245", "#5c5f63",
            "#8b8f94", "#b0b4b9", "#cfd2d6", "#e9ebee",
        ],
        accents: [
            "#1b2836", "#22364a", "#2c4560", "#3a5878", "#4c7098",
            "#6b93bd", "#8fb4d6", "#b3d0e8", "#d9e9f7",
        ]
    )

    static let both: [Theme] = [.light, .dark]

    static func of(_ appearance: NSAppearance) -> Theme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    func neutral(_ step: Int) -> String { Theme.step(neutrals, step) }
    func accent(_ step: Int) -> String { Theme.step(accents, step) }

    private static func step(_ ramp: [String], _ step: Int) -> String {
        let index = (step / 100) - 1
        return ramp[min(max(index, 0), ramp.count - 1)]
    }
}

/// The colours the UI asks for by name. Each one resolves against the appearance it is
/// drawn in, so switching to dark repaints the chrome without a view knowing about it.
enum Palette {
    static let bg = dynamic(\.bg)
    static let surface = dynamic(\.surface)
    static let text = dynamic(\.text)
    static let accent = dynamic(\.accent)
    static let onAccent = dynamic(\.onAccent)
    static let ochre = dynamic(\.ochre)
    static let ochreText = dynamic(\.ochreText)
    static let removed = dynamic(\.removed)
    static let removedText = dynamic(\.removedText)

    /// The divider is the text colour at 16%, not its own hex.
    static let divider = text.opacity(0.16)

    /// Steps run 100 to 900, as they do in the stylesheet.
    static func neutral(_ step: Int) -> Color {
        neutrals[index(step)]
    }

    static func accent(_ step: Int) -> Color {
        accents[index(step)]
    }

    /// Resolved once each. A view body asking for a colour should not mint a new one
    /// every time it draws, and two asks for the same token must give the same colour.
    private static let neutrals = (1...9).map { step in dynamic { $0.neutral(step * 100) } }
    private static let accents = (1...9).map { step in dynamic { $0.accent(step * 100) } }

    private static func index(_ step: Int) -> Int {
        min(max((step / 100) - 1, 0), 8)
    }

    static let bgHex = Theme.light.bg
    static let surfaceHex = Theme.light.surface
    static let textHex = Theme.light.text
    static let accentHex = Theme.light.accent
    static let ochreHex = Theme.light.ochre
    static let ochreTextHex = Theme.light.ochreText
    static let removedHex = Theme.light.removed
    static let removedTextHex = Theme.light.removedText
    static let neutralHexes = Theme.light.neutrals
    static let accentHexes = Theme.light.accents

    static func neutralHex(_ step: Int) -> String { Theme.light.neutral(step) }
    static func accentHex(_ step: Int) -> String { Theme.light.accent(step) }

    private static func dynamic(_ pick: @escaping (Theme) -> String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: pick(Theme.of(appearance)))
        })
    }
}

extension Color {
    init(hex: String) {
        let (red, green, blue) = channels(ofHex: hex)
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let (red, green, blue) = channels(ofHex: hex)
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

private func channels(ofHex hex: String) -> (Double, Double, Double) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let value = UInt64(digits, radix: 16) ?? 0
    return (
        Double((value >> 16) & 0xFF) / 255,
        Double((value >> 8) & 0xFF) / 255,
        Double(value & 0xFF) / 255
    )
}
