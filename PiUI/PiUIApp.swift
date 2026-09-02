import AppKit
import SwiftUI

@main
struct PiUIApp: App {
    /// The design's title bar reads FOREMAN; that was brief placeholder. One constant
    /// so the name is a single edit if it ever changes.
    static let name = "PiUI"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var shortcuts = Shortcuts()
    @State private var appearance = Appearance.saved

    /// An always-on log nobody can find is just disk use.
    private func revealLog() {
        Task {
            let folder = await EventLog.shared.directory
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
    }

    private func deleteLogs() {
        Task { await EventLog.shared.purge() }
    }

    private var appearanceChoice: Binding<Appearance> {
        Binding(
            get: { appearance },
            set: { choice in
                appearance = choice
                Appearance.saved = choice
                choice.apply()
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(shortcuts: shortcuts)
        }
        .defaultSize(width: 1100, height: 750)
        .windowStyle(.hiddenTitleBar)
        .commands {

            CommandGroup(after: .newItem) {
                Button(Agent.pi.newSessionTitle) {
                    shortcuts.askForNewSession(.pi)
                }
                .keyboardShortcut("t", modifiers: .control)

                Button(Agent.claude.newSessionTitle) {
                    shortcuts.askForNewSession(.claude)
                }
                .keyboardShortcut("t", modifiers: [.control, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Commands…") { shortcuts.askForPalette() }
                    .keyboardShortcut("k", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Reveal Log in Finder") { revealLog() }
                Button("Delete Logs") { deleteLogs() }
            }

            CommandMenu("View") {
                Picker("Appearance", selection: appearanceChoice) {
                    ForEach(Appearance.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
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
