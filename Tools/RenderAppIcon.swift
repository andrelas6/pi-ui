// Draws the app icon and writes every size the asset catalog asks for.
//
// The icon is generated rather than drawn by hand so it stays tied to the design
// system: the steel ground, the hairline frame and the four registration marks are
// the same ones the UI draws around every card, and the glyph is the bundled
// Barlow Condensed. Change a value here, run this, and the icon follows.
//
//   swift Tools/RenderAppIcon.swift PiUI/Fonts PiUI/Assets.xcassets/AppIcon.appiconset

import AppKit
import CoreText

let fontsDir = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])

for face in ["BarlowCondensed-Bold"] {
    CTFontManagerRegisterFontsForURL(
        fontsDir.appending(path: "\(face).ttf") as CFURL, .process, nil
    )
}

func color(_ hex: String, alpha: CGFloat = 1) -> NSColor {
    let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
    return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: alpha
    )
}

let steel = color("#5980a6")
let ink = color("#f5f5f8")

func draw(size: Int) -> Data {
    let side = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext

    // The macOS grid: the rounded square fills 80% of the canvas, the rest is breathing
    // room the system expects to be transparent.
    let plate = side * 0.8
    let origin = (side - plate) / 2
    let box = CGRect(x: origin, y: origin, width: plate, height: plate)
    let radius = plate * 0.225

    if size >= 128 {
        context.setShadow(
            offset: CGSize(width: 0, height: -plate * 0.012),
            blur: plate * 0.03,
            color: NSColor.black.withAlphaComponent(0.28).cgColor
        )
    }
    let plateShape = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
    steel.setFill()
    plateShape.fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // Below 128px a hairline frame and corner marks turn to mush; the glyph alone reads.
    if size >= 128 {
        let inset = plate * 0.115
        let frame = box.insetBy(dx: inset, dy: inset)
        let hairline = max(1, plate / 1024 * 4)

        ink.withAlphaComponent(0.34).setStroke()
        let rule = NSBezierPath(rect: frame)
        rule.lineWidth = hairline
        rule.stroke()

        // The same registration marks the app draws on every card.
        let arm = plate * 0.05
        ink.withAlphaComponent(0.85).setStroke()
        for x in [frame.minX, frame.maxX] {
            for y in [frame.minY, frame.maxY] {
                let mark = NSBezierPath()
                mark.move(to: CGPoint(x: x - arm, y: y))
                mark.line(to: CGPoint(x: x + arm, y: y))
                mark.move(to: CGPoint(x: x, y: y - arm))
                mark.line(to: CGPoint(x: x, y: y + arm))
                mark.lineWidth = hairline
                mark.stroke()
            }
        }
    }

    let glyphSize = plate * (size >= 128 ? 0.60 : 0.72)
    let font = NSFont(name: "BarlowCondensed-Bold", size: glyphSize)
        ?? .systemFont(ofSize: glyphSize, weight: .bold)

    // Centre the glyph's ink, not its layout box. A layout box carries descender space
    // that pi never uses, so centring that leaves the mark sitting visibly off.
    let ct = font as CTFont
    var characters = Array("π".utf16)
    var glyphs = [CGGlyph](repeating: 0, count: characters.count)
    CTFontGetGlyphsForCharacters(ct, &characters, &glyphs, characters.count)
    let inkBox = CTFontGetBoundingRectsForGlyphs(ct, .horizontal, &glyphs, nil, 1)

    context.setFillColor(ink.cgColor)
    var at = CGPoint(
        x: box.midX - inkBox.width / 2 - inkBox.minX,
        y: box.midY - inkBox.height / 2 - inkBox.minY
    )
    CTFontDrawGlyphs(ct, &glyphs, &at, 1, context)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let wanted: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for (name, size) in wanted {
    try! draw(size: size).write(to: outDir.appending(path: "\(name).png"))
}
print("rendered \(wanted.count) sizes")
