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
