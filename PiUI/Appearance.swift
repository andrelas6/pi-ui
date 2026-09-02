import AppKit

/// Light, dark, or whatever the Mac is set to. Setting it on `NSApp` is what carries the
/// choice everywhere at once: the chrome's dynamic colours, SwiftUI's own semantic ones,
/// and the transcript's `prefers-color-scheme` by way of the web view's appearance.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    private static let key = "appearance"

    static var saved: Appearance {
        get {
            guard let name = UserDefaults.standard.string(forKey: key) else { return .system }
            return Appearance(rawValue: name) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    @MainActor
    func apply() {
        NSApp.appearance = appearance
    }

    @MainActor
    static func applySaved() {
        saved.apply()
    }
}
