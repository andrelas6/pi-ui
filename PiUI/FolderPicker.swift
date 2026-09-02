import AppKit

enum FolderPicker {
    @MainActor
    static func pick(for agent: Agent = .pi) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Pick the folder \(agent.name) should work in"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
