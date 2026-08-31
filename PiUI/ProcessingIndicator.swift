import SwiftUI

/// Shown while a turn is running: a spinner, a phrase that changes so the row does not
/// look frozen, and how long it has been going.
struct ProcessingIndicator: View {
    let stop: () -> Void

    @State private var phrase = 0
    @State private var seconds = 0

    private static let phrases = [
        "processing…",
        "cooking",
        "getting there…",
        "reading the diff",
        "thinking it through",
        "almost",
    ]

    private let phraseTick = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()
    private let secondTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: Space.two) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)

            Kicker(
                text: Self.phrases[phrase % Self.phrases.count],
                size: 15,
                tracking: 0.08,
                color: Palette.accent(700)
            )
            // Fixed so a longer phrase does not shove the timer sideways every 1.6s.
            .frame(minWidth: 220, alignment: .leading)

            Text("\(elapsed) · esc to interrupt")
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.neutral(500))

            Spacer()
        }
        .padding(.horizontal, Space.eight)
        .padding(.vertical, Space.two)
        .onReceive(phraseTick) { _ in phrase += 1 }
        .onReceive(secondTick) { _ in seconds += 1 }
    }

    private var elapsed: String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}
