import AppKit

enum FolderPicker {
    @MainActor
    static func pick() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Pick the folder pi should work in"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
