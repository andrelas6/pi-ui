import SwiftUI

@main
struct PiUIApp: App {
    /// The design's title bar reads FOREMAN; that was brief placeholder. One constant
    /// so the name is a single edit if it ever changes.
    static let name = "PiUI"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var shortcuts = Shortcuts()

    var body: some Scene {
        WindowGroup {
            ContentView(shortcuts: shortcuts)
        }
        .defaultSize(width: 1100, height: 750)
        .windowStyle(.hiddenTitleBar)
        .commands {

            CommandGroup(after: .newItem) {
                Button("New Session…") {
                    shortcuts.askForNewSession()
                }
                .keyboardShortcut("t", modifiers: .control)
            }

            CommandGroup(after: .toolbar) {
                Button("Commands…") { shortcuts.askForPalette() }
                    .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("Sessions") {
                ForEach(1...9, id: \.self) { number in
                    Button("Session \(number)") {
                        shortcuts.jumpTo = number
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }
            }
        }
    }
}
