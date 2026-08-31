import SwiftUI

/// The design's recurring label: condensed, uppercase, widely tracked. Tracking is given
/// in em, as the stylesheet writes it, and multiplied by the size here.
struct Kicker: View {
    let text: String
    var size: CGFloat = 12
    var tracking: CGFloat = 0.16
    var color: Color = Palette.neutral(700)
    var bold = false

    var body: some View {
        Text(text.uppercased())
            .font(Typeface.heading(size, bold: bold))
            .tracking(size * tracking)
            .foregroundStyle(color)
    }
}

/// Every division in this UI is a 1px rule in the divider colour — never a shadow,
/// never a gap.
struct Hairline: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(Palette.divider)
            .frame(width: vertical ? Frame.hairline : nil)
            .frame(height: vertical ? nil : Frame.hairline)
    }
}

/// The four `+` registration marks a framed object wears. Cards stay transparent line
/// drawings; the marks are what make them read as blueprint objects.
struct CornerMarks: View {
    var color: Color = Palette.divider
    var length: CGFloat = 5

    var body: some View {
        GeometryReader { frame in
            ForEach(Corner.allCases, id: \.self) { corner in
                mark
                    .position(
                        x: corner.leading ? 0 : frame.size.width,
                        y: corner.top ? 0 : frame.size.height
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var mark: some View {
        ZStack {
            Rectangle().fill(color).frame(width: Frame.hairline, height: length * 2)
            Rectangle().fill(color).frame(width: length * 2, height: Frame.hairline)
        }
    }

    enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var top: Bool { self == .topLeading || self == .topTrailing }
        var leading: Bool { self == .topLeading || self == .bottomLeading }
    }
}
