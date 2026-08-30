import SwiftUI

@main
struct PiUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var shortcuts = Shortcuts()

    var body: some Scene {
        WindowGroup {
            ContentView(shortcuts: shortcuts)
        }
        .defaultSize(width: 1100, height: 750)
        .commands {
            SidebarCommands()

            CommandGroup(after: .newItem) {
                Button("New Session…") {
                    shortcuts.askForNewSession()
                }
                .keyboardShortcut("t", modifiers: .command)
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
