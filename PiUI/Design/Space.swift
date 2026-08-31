import CoreGraphics

/// The 0.85× density scale from the design system. These are the only spacing values
/// the UI uses — anything else is a mistake, not a judgement call.
enum Space {
    static let one: CGFloat = 3.4
    static let two: CGFloat = 6.8
    static let three: CGFloat = 10.2
    static let four: CGFloat = 13.6
    static let six: CGFloat = 20.4
    static let eight: CGFloat = 27.2

    static let all: [CGFloat] = [one, two, three, four, six, eight]
}

/// Fixed measurements the design specifies outright.
enum Frame {
    static let titleBar: CGFloat = 38
    static let sessionRail: CGFloat = 272
    static let fileTree: CGFloat = 264
    static let mainMinimum: CGFloat = 520
    static let logMaximum: CGFloat = 760
    static let hairline: CGFloat = 1
    static let activeMarker: CGFloat = 2
    static let statusDot: CGFloat = 8
}

/// Present in the token sheet, but this UI is square-cornered throughout: cards,
/// buttons and figures are never rounded. Kept so the scale is recorded, not used.
enum Radius {
    static let small: CGFloat = 2
    static let medium: CGFloat = 4
    static let large: CGFloat = 7
}
