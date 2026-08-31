import SwiftUI

struct TitleBar: View {
    let appName: String
    let path: String?
    let sessionCount: Int
    let needingInput: Int

    /// The native title bar is hidden, so the traffic lights float over this row and
    /// the name has to start clear of them.
    private let trafficLightGap: CGFloat = 78

    var body: some View {
        HStack(spacing: Space.three) {
            Kicker(text: appName, size: 13, tracking: 0.14, color: Palette.text, bold: true)

            if let path {
                Text(path)
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.neutral(600))
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: Space.four)

            Kicker(
                text: "\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")",
                size: 11,
                tracking: 0.1,
                color: Palette.neutral(600)
            )

            if needingInput > 0 {
                Kicker(
                    text: "\(needingInput) needs input",
                    size: 11,
                    tracking: 0.1,
                    color: Palette.accent(700)
                )
            }
        }
        .padding(.leading, trafficLightGap)
        .padding(.trailing, Space.four)
        .frame(height: Frame.titleBar)
        .frame(maxWidth: .infinity)
        .background(Palette.neutral(100))
    }
}

extension URL {
    /// `/Users/me/work/app` reads as `~/work/app`, as the design shows it.
    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
