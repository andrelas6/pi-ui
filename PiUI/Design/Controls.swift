import SwiftUI

/// The frame every card, figure and primary button wears: a hairline border and four
/// registration marks. Cards stay transparent line drawings — only the primary button
/// is filled.
struct Blueprint: ViewModifier {
    var fill: Color = .clear
    var stroke: Color = Palette.neutral(400)

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().stroke(stroke, lineWidth: Frame.hairline))
            .overlay(CornerMarks(color: stroke))
    }
}

extension View {
    func blueprint(fill: Color = .clear, stroke: Color = Palette.neutral(400)) -> some View {
        modifier(Blueprint(fill: fill, stroke: stroke))
    }
}

/// A small outlined label — square, hairline, mono.
struct OutlineTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typeface.mono(11))
            .foregroundStyle(Palette.neutral(700))
            .padding(.horizontal, Space.two)
            .padding(.vertical, 1)
            .overlay(Rectangle().stroke(Palette.neutral(400), lineWidth: Frame.hairline))
    }
}

/// The one solid object on the board.
struct PrimaryButton: View {
    let title: String
    var icon: String?
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.one) {
                Text(title.uppercased())
                    .font(Typeface.heading(12))
                    .tracking(12 * 0.06)
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, Space.three)
            .frame(height: 24)
            .background(enabled ? Palette.accent : Palette.neutral(400))
            .overlay(CornerMarks(color: Palette.accent(800)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String?
    var trailingIcon: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.one) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .light))
                }
                Text(title.uppercased())
                    .font(Typeface.heading(12))
                    .tracking(12 * 0.06)
                if let trailingIcon {
                    Image(systemName: trailingIcon).font(.system(size: 9, weight: .medium))
                }
            }
            .foregroundStyle(Palette.neutral(700))
            .padding(.horizontal, Space.two)
            .frame(height: 24)
            .background(hovering ? Palette.accent(100) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct GhostIconButton: View {
    let icon: String
    var size: CGFloat = 16
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .light))
                .foregroundStyle(Palette.neutral(700))
                .frame(width: 24, height: 24)
                .background(hovering ? Palette.accent(100) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Drawn in the design but with nothing behind it yet. Says so rather than doing
/// nothing when pressed.
struct NotYetButton: View {
    let icon: String
    let what: String

    @State private var explaining = false

    var body: some View {
        GhostIconButton(icon: icon) { explaining = true }
            .popover(isPresented: $explaining, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: Space.two) {
                    Kicker(text: what, size: 12, color: Palette.text)
                    Text("Not yet implemented.")
                        .font(Typeface.body(12))
                        .foregroundStyle(Palette.neutral(600))
                }
                .padding(Space.four)
                .background(Palette.neutral(100))
            }
            .help(what)
    }
}
