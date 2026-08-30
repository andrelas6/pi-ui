import AppKit
import SwiftUI

struct SidebarView: View {
    let store: SessionStore
    let chat: Chat?
    let open: (SavedSession) -> Void
    let start: (URL) -> Void

    var body: some View {
        List {
            ForEach(store.sessions.sorted { $0.lastOpenedAt > $1.lastOpenedAt }) { session in
                SessionRow(
                    session: session,
                    isMissing: store.isMissing(session.id),
                    isOpen: chat?.openSessionId == session.id
                )
                .contentShape(.rect)
                .onTapGesture { open(session) }
            }
        }
        .overlay {
            if store.sessions.isEmpty {
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
            start(folder)
        }
    }
}

private struct SessionRow: View {
    let session: SavedSession
    let isMissing: Bool
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isOpen ? "circle.fill" : "folder")
                .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .lineLimit(1)
                Text(session.folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("This session's file is gone. pi cannot reopen its history.")
            }
        }
        .padding(.vertical, 2)
    }
}
