import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// macOS adds its own "New Tab" on ⌘T whenever window tabbing is on, and that
    /// shadows the app's own ⌘T. This app has no use for tabs.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        Typeface.register()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
