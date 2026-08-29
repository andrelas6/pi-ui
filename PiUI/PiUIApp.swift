import SwiftUI

@main
struct PiUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 750)
        .commands {
            SidebarCommands()
        }
    }
}
