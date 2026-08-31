import AppKit
import CoreText
import SwiftUI

/// Barlow rides in the bundle rather than being installed, so it has to be registered
/// with the font manager before anything can ask for it by name.
enum Typeface {
    static let headingRegular = "BarlowCondensed-SemiBold"
    static let headingBold = "BarlowCondensed-Bold"
    static let bodyRegular = "Barlow-Regular"
    static let bodyMedium = "Barlow-Medium"

    static let bundled = [headingRegular, headingBold, bodyRegular, bodyMedium]

    /// Names the transcript's CSS uses. The faces are registered process-wide, so the
    /// web view resolves them by family name without a @font-face rule.
    static let headingFamily = "Barlow Condensed"
    static let bodyFamily = "Barlow"
    static let monoStack = "ui-monospace, Menlo, monospace"

    @MainActor private(set) static var registered = false

    @MainActor
    static func register() {
        guard !registered else { return }

        let urls = bundled.compactMap { Bundle.main.url(forResource: $0, withExtension: "ttf") }
        guard !urls.isEmpty else { return }

        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true) { _, _ in true }
        registered = true
    }

    /// True only when every bundled face actually resolves. A missing font falls back
    /// silently to the system face, which looks like a design mistake rather than a
    /// packaging one.
    static var allResolve: Bool {
        bundled.allSatisfy { NSFont(name: $0, size: 12) != nil }
    }

    static func heading(_ size: CGFloat, bold: Bool = false) -> Font {
        named(bold ? headingBold : headingRegular, size: size, fallback: bold ? .bold : .semibold)
    }

    static func body(_ size: CGFloat, medium: Bool = false) -> Font {
        named(medium ? bodyMedium : bodyRegular, size: size, fallback: medium ? .medium : .regular)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    private static func named(_ name: String, size: CGFloat, fallback: Font.Weight) -> Font {
        guard NSFont(name: name, size: size) != nil else {
            return .system(size: size, weight: fallback)
        }
        return .custom(name, fixedSize: size)
    }
}
