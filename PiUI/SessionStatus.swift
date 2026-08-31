import SwiftUI

/// What a session is doing, as the rail draws it. The dot carries this alone — the
/// design has no status text.
enum SessionStatus: Equatable {
    case done
    case working
    case needsInput

    var color: Color {
        switch self {
        case .done: Palette.neutral(400)
        case .working: Palette.accent
        case .needsInput: Palette.ochre
        }
    }

    /// How far the pulse fades, and how long a beat takes. Done does not move.
    var faded: Double {
        switch self {
        case .done: 1
        case .working: 0.28
        case .needsInput: 0.3
        }
    }

    var beat: Double? {
        switch self {
        case .done: nil
        case .working: 2
        case .needsInput: 1.6
        }
    }

    var label: String {
        switch self {
        case .done: "done"
        case .working: "working"
        case .needsInput: "needs input"
        }
    }

    static let all: [SessionStatus] = [.done, .working, .needsInput]
}

/// A square, not a circle, and it pulses by opacity alone — no scaling.
struct StatusDot: View {
    let status: SessionStatus
    var size: CGFloat = Frame.statusDot

    @State private var faded = false

    var body: some View {
        Rectangle()
            .fill(status.color)
            .frame(width: size, height: size)
            .opacity(faded ? status.faded : 1)
            .animation(pulse, value: faded)
            .onAppear { faded = status.beat != nil }
            .onChange(of: status) { _, _ in faded = status.beat != nil }
    }

    private var pulse: Animation? {
        guard let beat = status.beat else { return nil }
        return .easeInOut(duration: beat).repeatForever(autoreverses: true)
    }
}
