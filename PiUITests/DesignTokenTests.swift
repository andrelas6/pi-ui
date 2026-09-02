import SwiftUI
import Testing

@testable import PiUI

struct DesignTokenTests {
    @Test func rampsRunOneHundredToNineHundred() {
        #expect(Palette.neutralHexes.count == 9)
        #expect(Palette.accentHexes.count == 9)
        #expect(Palette.neutralHex(100) == "#f5f5f8")
        #expect(Palette.neutralHex(900) == "#2b2b2d")
        #expect(Palette.accentHex(100) == "#eef6ff")
        #expect(Palette.accentHex(900) == "#1d2d3d")
    }

    @Test func readsTheMiddleOfARamp() {
        #expect(Palette.neutralHex(400) == "#b7b7ba")
        #expect(Palette.accentHex(700) == "#416180")
    }

    /// A step outside the ramp clamps rather than crashing a view mid-render.
    @Test func clampsAStepThatDoesNotExist() {
        #expect(Palette.neutralHex(0) == Palette.neutralHex(100))
        #expect(Palette.neutralHex(5000) == Palette.neutralHex(900))
    }

    @Test func keepsTheOchreOutsideTheSteelPalette() {
        #expect(Palette.ochreHex == "#b07d2e")
        #expect(Palette.ochreTextHex == "#7d5719")
        #expect(Palette.neutralHexes.contains(Palette.ochreHex) == false)
        #expect(Palette.accentHexes.contains(Palette.ochreHex) == false)
    }

    /// Two colours sit outside the steel ramps, and both are deliberate.
    @Test func keepsTheRemovedColourOutsideTheRamps() {
        #expect(Palette.removedHex == "#f5dbd6")
        #expect(Palette.removedTextHex == "#5f2d27")
        #expect(Palette.neutralHexes.contains(Palette.removedHex) == false)
        #expect(Palette.accentHexes.contains(Palette.removedHex) == false)
    }

    @Test func usesTheDensityScale() {
        #expect(Space.all == [3.4, 6.8, 10.2, 13.6, 20.4, 27.2])
    }

    @Test func keepsTheSpecifiedMeasurements() {
        #expect(Frame.titleBar == 38)
        #expect(Frame.sessionRail == 272)
        #expect(Frame.fileTree == 264)
        #expect(Frame.logMaximum == 760)
    }

    @Test func readsAHexIntoAColour() {
        let resolved = NSColor(Color(hex: "#5980a6")).usingColorSpace(.sRGB)
        #expect(Int((resolved?.redComponent ?? 0) * 255 + 0.5) == 0x59)
        #expect(Int((resolved?.greenComponent ?? 0) * 255 + 0.5) == 0x80)
        #expect(Int((resolved?.blueComponent ?? 0) * 255 + 0.5) == 0xa6)
    }

    @Test func acceptsAHexWithoutItsHash() {
        let withHash = NSColor(Color(hex: "#b07d2e")).usingColorSpace(.sRGB)
        let without = NSColor(Color(hex: "b07d2e")).usingColorSpace(.sRGB)
        #expect(withHash?.redComponent == without?.redComponent)
    }
}

/// The dark theme is not a tweak of the light one — it is a second full set, and the
/// ramps run the other way so every call site keeps its meaning.
struct DarkThemeTests {
    @Test func fillsBothRampsInFull() {
        #expect(Theme.dark.neutrals.count == 9)
        #expect(Theme.dark.accents.count == 9)
    }

    /// The invariant the whole design rests on: low steps are the quiet surface and high
    /// steps the strong text. Light runs pale to dark to get that; dark runs dark to pale.
    @Test func runsTheRampsOppositeToLight() {
        #expect(descends(Theme.light.neutrals))
        #expect(descends(Theme.light.accents))
        #expect(ascends(Theme.dark.neutrals))
        #expect(ascends(Theme.dark.accents))
    }

    /// A half-filled theme would inherit light values and look almost right, which is
    /// worse than looking broken.
    @Test func repaintsEveryToken() {
        #expect(Theme.dark.bg != Theme.light.bg)
        #expect(Theme.dark.surface != Theme.light.surface)
        #expect(Theme.dark.text != Theme.light.text)
        #expect(Theme.dark.accent != Theme.light.accent)
        #expect(Theme.dark.onAccent != Theme.light.onAccent)
        #expect(Theme.dark.ochre != Theme.light.ochre)
        #expect(Theme.dark.ochreText != Theme.light.ochreText)
        #expect(Theme.dark.removed != Theme.light.removed)
        #expect(Theme.dark.removedText != Theme.light.removedText)
        #expect(Theme.dark.shadow != Theme.light.shadow)
        #expect(Set(Theme.dark.neutrals).isDisjoint(with: Theme.light.neutrals))
        #expect(Set(Theme.dark.accents).isDisjoint(with: Theme.light.accents))
    }

    /// The ground is dark and the type is light — the other way round from light mode.
    @Test func invertsTheGroundAndTheType() {
        #expect(luminance(Theme.dark.bg) < 0.2)
        #expect(luminance(Theme.dark.text) > 0.8)
        #expect(luminance(Theme.light.bg) > 0.8)
        #expect(luminance(Theme.light.text) < 0.2)
    }

    /// Both off-palette colours stay off-palette in dark, as they are in light.
    @Test func keepsTheOffPaletteColoursOutsideTheRamps() {
        for hex in [Theme.dark.ochre, Theme.dark.removed] {
            #expect(Theme.dark.neutrals.contains(hex) == false)
            #expect(Theme.dark.accents.contains(hex) == false)
        }
    }

    /// A dark ground needs black to sink into. Reusing the last neutral would tint the
    /// shadow light and read as a glow.
    @Test func mixesDarkShadowsFromBlack() {
        #expect(Theme.light.shadow == Theme.light.neutrals[8])
        #expect(luminance(Theme.dark.shadow) == 0)
    }

    /// The label on a filled accent button cannot be a ramp step, because the ramp flips.
    @Test func keepsTheAccentLabelLegibleInBoth() {
        for theme in Theme.both {
            #expect(abs(luminance(theme.onAccent) - luminance(theme.accent)) > 0.4)
        }
    }

    @Test func clampsADarkStepThatDoesNotExist() {
        #expect(Theme.dark.neutral(0) == Theme.dark.neutral(100))
        #expect(Theme.dark.neutral(5000) == Theme.dark.neutral(900))
    }

    /// The light aliases on `Palette` still name the light theme, so nothing that reads
    /// a hex string directly changed meaning.
    @Test func leavesTheLightAliasesAlone() {
        #expect(Palette.bgHex == Theme.light.bg)
        #expect(Palette.neutralHexes == Theme.light.neutrals)
        #expect(Palette.accentHex(700) == Theme.light.accent(700))
    }

    @Test func picksTheThemeFromTheAppearance() {
        #expect(Theme.of(NSAppearance(named: .darkAqua)!).bg == Theme.dark.bg)
        #expect(Theme.of(NSAppearance(named: .aqua)!).bg == Theme.light.bg)
    }

    private func ascends(_ ramp: [String]) -> Bool {
        zip(ramp, ramp.dropFirst()).allSatisfy { luminance($0) < luminance($1) }
    }

    private func descends(_ ramp: [String]) -> Bool {
        zip(ramp, ramp.dropFirst()).allSatisfy { luminance($0) > luminance($1) }
    }

    private func luminance(_ hex: String) -> Double {
        guard let color = NSColor(hex: hex).usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * color.redComponent
            + 0.587 * color.greenComponent
            + 0.114 * color.blueComponent
    }
}

/// The chrome never asks which theme it is in — it asks for a token and AppKit resolves
/// it against the appearance being drawn. These prove that resolution actually happens.
@MainActor
struct PaletteResolutionTests {
    @Test func resolvesTheGroundToEachTheme() {
        #expect(hex(Palette.bg, in: .aqua) == Theme.light.bg)
        #expect(hex(Palette.bg, in: .darkAqua) == Theme.dark.bg)
    }

    @Test func resolvesTheRampsToEachTheme() {
        for step in stride(from: 100, through: 900, by: 100) {
            #expect(hex(Palette.neutral(step), in: .aqua) == Theme.light.neutral(step))
            #expect(hex(Palette.neutral(step), in: .darkAqua) == Theme.dark.neutral(step))
            #expect(hex(Palette.accent(step), in: .aqua) == Theme.light.accent(step))
            #expect(hex(Palette.accent(step), in: .darkAqua) == Theme.dark.accent(step))
        }
    }

    @Test func resolvesTheOffPaletteColoursToEachTheme() {
        #expect(hex(Palette.ochre, in: .darkAqua) == Theme.dark.ochre)
        #expect(hex(Palette.removedText, in: .darkAqua) == Theme.dark.removedText)
        #expect(hex(Palette.onAccent, in: .darkAqua) == Theme.dark.onAccent)
    }

    /// Asking twice must give the same colour, or `==` comparisons on tokens break and
    /// every view body mints a fresh colour as it draws.
    @Test func handsBackTheSameColourEachTime() {
        #expect(Palette.ochre == Palette.ochre)
        #expect(Palette.neutral(400) == Palette.neutral(400))
        #expect(Palette.neutral(400) != Palette.neutral(500))
    }

    private func hex(_ color: Color, in appearance: NSAppearance.Name) -> String {
        var found = ""
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            guard let resolved = NSColor(color).usingColorSpace(.sRGB) else { return }
            found = String(
                format: "#%02x%02x%02x",
                Int(resolved.redComponent * 255 + 0.5),
                Int(resolved.greenComponent * 255 + 0.5),
                Int(resolved.blueComponent * 255 + 0.5)
            )
        }
        return found
    }
}

@MainActor
@Suite(.serialized)
struct AppearanceTests {
    @Test func defaultsToFollowingTheSystem() {
        withSavedAppearance {
            UserDefaults.standard.removeObject(forKey: "appearance")
            #expect(Appearance.saved == .system)
        }
    }

    @Test func remembersAChoice() {
        withSavedAppearance {
            Appearance.saved = .dark
            #expect(Appearance.saved == .dark)
            Appearance.saved = .light
            #expect(Appearance.saved == .light)
        }
    }

    /// A value written by an older or newer build should not leave the app with no theme.
    @Test func fallsBackWhenTheStoredValueIsJunk() {
        withSavedAppearance {
            UserDefaults.standard.set("solarized", forKey: "appearance")
            #expect(Appearance.saved == .system)
        }
    }

    /// System means "no override" — anything else pins the app regardless of the Mac.
    @Test func onlySystemLeavesTheAppearanceUnset() {
        #expect(Appearance.system.appearance == nil)
        #expect(Appearance.light.appearance?.name == .aqua)
        #expect(Appearance.dark.appearance?.name == .darkAqua)
    }

    @Test func offersThreeChoices() {
        #expect(Appearance.allCases.map(\.label) == ["System", "Light", "Dark"])
    }

    private func withSavedAppearance(_ body: () -> Void) {
        let original = UserDefaults.standard.string(forKey: "appearance")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "appearance")
            } else {
                UserDefaults.standard.removeObject(forKey: "appearance")
            }
        }
        body()
    }
}

struct StylesheetTests {
    private let css = Stylesheet.rootVariables

    /// The whole point of generating it: one value, both languages.
    @Test func carriesTheSameValuesAsSwift() {
        #expect(css.contains("--color-bg: \(Palette.bgHex);"))
        #expect(css.contains("--color-accent: \(Palette.accentHex);"))
        #expect(css.contains("--color-ochre: \(Palette.ochreHex);"))
    }

    @Test func carriesBothOffPaletteColours() {
        #expect(css.contains("--color-ochre: \(Palette.ochreHex);"))
        #expect(css.contains("--color-removed: \(Palette.removedHex);"))
        #expect(css.contains("--color-removed-text: \(Palette.removedTextHex);"))
    }

    @Test func writesBothRampsInFull() {
        for step in stride(from: 100, through: 900, by: 100) {
            #expect(css.contains("--color-neutral-\(step): \(Palette.neutralHex(step));"))
            #expect(css.contains("--color-accent-\(step): \(Palette.accentHex(step));"))
        }
    }

    /// The scale skips 5 and 7, so the names are not simply 1 through 6.
    @Test func namesTheSpacingStepsAsTheSheetDoes() {
        #expect(css.contains("--space-1: 3.4px;"))
        #expect(css.contains("--space-4: 13.6px;"))
        #expect(css.contains("--space-8: 27.2px;"))
        #expect(css.contains("--space-5:") == false)
        #expect(css.contains("--space-7:") == false)
    }

    @Test func namesTheBundledFamilies() {
        #expect(css.contains("--font-heading: \"Barlow Condensed\""))
        #expect(css.contains("--font-body: \"Barlow\""))
        #expect(css.contains("--font-mono: ui-monospace"))
    }

    @Test func opensAndClosesTheBlock() {
        #expect(css.hasPrefix(":root {"))
        #expect(css.hasSuffix("}"))
    }

    @Test func carriesTheDarkThemeBehindAMediaQuery() {
        #expect(css.contains("@media (prefers-color-scheme: dark)"))
        #expect(dark.contains("--color-bg: \(Theme.dark.bg);"))
        #expect(dark.contains("--color-text: \(Theme.dark.text);"))
        #expect(dark.contains("--color-neutral-100: \(Theme.dark.neutral(100));"))
        #expect(dark.contains("--color-accent-900: \(Theme.dark.accent(900));"))
    }

    /// The reason both blocks are written by one function: a token defined in only one
    /// of them would fall back to the other theme's value and look almost right.
    @Test func definesEveryColourInBothThemes() {
        #expect(names(in: light).isEmpty == false)
        #expect(names(in: light) == names(in: dark))
    }

    @Test func namesTheLabelForAFilledButton() {
        #expect(light.contains("--color-on-accent: \(Theme.light.onAccent);"))
        #expect(dark.contains("--color-on-accent: \(Theme.dark.onAccent);"))
    }

    /// Shadows sink into a dark ground rather than glowing off it.
    @Test func mixesEachThemesShadowsFromItsOwnColour() {
        #expect(light.contains("--shadow-sm: 0 1px 2px color-mix(in srgb, \(Theme.light.shadow) 14%, transparent);"))
        #expect(dark.contains("--shadow-sm: 0 1px 2px color-mix(in srgb, \(Theme.dark.shadow) 14%, transparent);"))
    }

    /// Type and spacing do not vary by appearance, so they are written once.
    @Test func writesTheMetricsOnlyOnce() {
        #expect(css.components(separatedBy: "--font-body:").count == 2)
        #expect(css.components(separatedBy: "--space-4:").count == 2)
        #expect(dark.contains("--font-body:") == false)
        #expect(dark.contains("--space-4:") == false)
    }

    private var light: String {
        String(css.prefix(upTo: css.range(of: "@media")!.lowerBound))
    }

    private var dark: String {
        String(css.suffix(from: css.range(of: "@media")!.lowerBound))
    }

    private func names(in block: String) -> Set<String> {
        Set(
            block
                .components(separatedBy: "--color-")
                .dropFirst()
                .compactMap { $0.components(separatedBy: ":").first }
        )
    }
}

@MainActor
struct TypefaceTests {
    /// Registration is silent when the files are missing, and a missing face falls back
    /// to the system font — which reads as a design mistake rather than a packaging one.
    @Test func everyBundledFaceResolves() {
        Typeface.register()

        #expect(Typeface.registered)
        #expect(Typeface.allResolve, "a bundled .ttf did not reach Contents/Resources")

        for name in Typeface.bundled {
            #expect(NSFont(name: name, size: 13) != nil, "missing face: \(name)")
        }
    }

    @Test func registeringTwiceIsHarmless() {
        Typeface.register()
        Typeface.register()
        #expect(Typeface.allResolve)
    }

    @Test func bundlesOnlyTheFacesTheDesignUses() {
        #expect(Typeface.bundled.count == 4)
        #expect(Typeface.bundled.contains("BarlowCondensed-SemiBold"))
        #expect(Typeface.bundled.contains("Barlow-Regular"))
    }
}
