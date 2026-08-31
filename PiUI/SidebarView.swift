import AppKit
import SwiftUI

struct SidebarView: View {
    let store: SessionStore
    let pool: ChatPool?
    let open: (SavedSession) -> Void
    let start: (URL) -> Void

    @State private var selected: String?
    @State private var renaming: SavedSession?
    @State private var draftName = ""
    @State private var deleting: SavedSession?
    @State private var deleteFailed: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            sessions
        }
        .background(Palette.bg)
    }

    private var header: some View {
        HStack {
            Kicker(text: "sessions")
            Spacer()
            Button(action: pickFolder) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.neutral(600))
            .help("Pick a folder to run pi in (⌃T)")
        }
        .padding(.horizontal, Space.four)
        .padding(.top, Space.four)
        .padding(.bottom, Space.three)
    }

    private var sessions: some View {
        List(selection: $selected) {
            ForEach(store.groups) { group in
                Section(group.title) {
                    ForEach(group.sessions) { session in
                        row(for: session)
                        .tag(session.id)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Rename…") { startRenaming(session) }
                            Button("Delete…", role: .destructive) { deleting = session }
                        }
                    }
                }
            }
        }
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .overlay {
            if store.sessions.isEmpty {
                Kicker(text: "no sessions", size: 12, color: Palette.neutral(500))
            }
        }
        .onChange(of: selected) { _, id in
            guard let id, let session = store.session(id) else { return }
            open(session)
        }
        .onChange(of: pool?.current?.openSessionId) { _, id in
            selected = id
        }
        .alert("Rename session", isPresented: renamingBinding) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { commitRename() }
        } message: {
            Text("Shown in the sidebar, and in pi's own session picker.")
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: deletingBinding,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { commitDelete() }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text(deleting.map { "\($0.title) and its history move to the Trash." } ?? "")
        }
        .alert("Could not delete", isPresented: deleteFailedBinding) {
            Button("OK") { deleteFailed = nil }
        } message: {
            Text(deleteFailed ?? "")
        }
    }

    private func row(for session: SavedSession) -> SessionRow {
        SessionRow(
            session: session,
            number: numbers[session.id],
            branch: store.branch(for: session),
            isMissing: store.isMissing(session.id),
            isRunning: pool?.chat(for: session.id) != nil,
            isBusy: pool?.isBusy(session.id) ?? false,
            isWaiting: pool?.isWaiting(session.id) ?? false,
            isDone: pool?.isFinishedUnseen(session.id) ?? false
        )
    }

    /// Only the first nine rows get a shortcut, matching ⌘1–⌘9.
    private var numbers: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: store.ordered.prefix(9).enumerated().map { ($0.element.id, $0.offset + 1) }
        )
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private var deleteFailedBinding: Binding<Bool> {
        Binding(get: { deleteFailed != nil }, set: { if !$0 { deleteFailed = nil } })
    }

    private func startRenaming(_ session: SavedSession) {
        draftName = session.name ?? session.folder.lastPathComponent
        renaming = session
    }

    private func commitRename() {
        guard let session = renaming else { return }
        pool?.chat(for: session.id)?.rename(session.id, to: draftName)
        store.rename(session.id, to: draftName)
        renaming = nil
    }

    private func commitDelete() {
        guard let session = deleting else { return }
        pool?.drop(session.id)
        do {
            try store.trash(session.id)
        } catch {
            deleteFailed = error.localizedDescription
        }
        deleting = nil
    }

    private func pickFolder() {
        guard let folder = FolderPicker.pick() else { return }
        start(folder)
    }
}

private struct SessionRow: View {
    let session: SavedSession
    let number: Int?
    let branch: String?
    let isMissing: Bool
    let isRunning: Bool
    let isBusy: Bool
    let isWaiting: Bool
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
                    .frame(width: 10)
            } else {
                Image(systemName: isRunning ? "circle.fill" : "bubble.left")
                    .foregroundStyle(isRunning ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .lineLimit(1)
                if let branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let number {
                Text("⌘\(number)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isWaiting {
                WaitingDot()
            } else if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .help("Finished while you were elsewhere")
            }

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("This session's file is gone. Opening it starts an empty one.")
            }
        }
        .padding(.vertical, 2)
    }
}
