import AppKit
import SwiftUI

struct SidebarView: View {
    let chat: Chat

    var body: some View {
        List {
            if let folder = chat.folder {
                Label(folder.lastPathComponent, systemImage: "folder")
                    .help(folder.path)
            }
        }
        .overlay {
            if chat.folder == nil {
                ContentUnavailableView(
                    "No sessions",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Pick a folder to start one.")
                )
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem {
                Button(action: pickFolder) {
                    Label("New session", systemImage: "plus")
                }
                .help("Pick a folder to run pi in")
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Pick the folder pi should work in"

        if panel.runModal() == .OK, let folder = panel.url {
            chat.open(folder)
        }
    }
}
