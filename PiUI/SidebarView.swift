import AppKit
import SwiftUI

struct SidebarView: View {
    let store: SessionStore
    let pool: ChatPool?
    let open: (SavedSession) -> Void
    let start: (URL) -> Void

    @State private var renaming: SavedSession?
    @State private var draftName = ""
    @State private var deleting: SavedSession?
    @State private var deleteFailed: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            sessions
            Hairline()
            Legend()
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.ordered) { session in
                    row(for: session)
                        .contextMenu {
                            Button("Rename…") { startRenaming(session) }
                            Button("Delete…", role: .destructive) { deleting = session }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if store.sessions.isEmpty {
                Kicker(text: "no sessions", size: 12, color: Palette.neutral(500))
            }
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

    private func row(for session: SavedSession) -> some View {
        SessionRow(
            session: session,
            number: numbers[session.id],
            branch: store.branch(for: session),
            status: status(of: session),
            isMissing: store.isMissing(session.id),
            isActive: pool?.current?.openSessionId == session.id
        )
        .onTapGesture { open(session) }
    }

    private func status(of session: SavedSession) -> SessionStatus {
        if pool?.isWaiting(session.id) == true { return .needsInput }
        if pool?.isBusy(session.id) == true { return .working }
        return .done
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
    let status: SessionStatus
    let isMissing: Bool
    let isActive: Bool

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Palette.accent : .clear)
                .frame(width: Frame.activeMarker)

            HStack(alignment: .top, spacing: 0) {
                StatusDot(status: status)
                    .frame(width: 14, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(Typeface.heading(16))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 22)

                    if let branch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 11, weight: .light))
                            Text(branch)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .font(Typeface.mono(10.5))
                        .foregroundStyle(Palette.neutral(600))
                    }
                }

                Spacer(minLength: Space.two)

                if isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.ochre)
                        .frame(height: 22)
                        .help("This session's file is gone. Opening it starts an empty one.")
                }

                if let number {
                    Text("⌘\(number)")
                        .font(Typeface.mono(11))
                        .foregroundStyle(Palette.neutral(500))
                        .frame(height: 22)
                }
            }
            .padding(Space.three)
        }
        .contentShape(.rect)
        .background(background)
        .overlay { if isActive { CornerMarks() } }
        .onHover { hovering = $0 }
    }

    private var background: Color {
        isActive || hovering ? Palette.accent(100) : .clear
    }
}

/// Three states is not obvious from three coloured squares, so the rail says which
/// is which.
private struct Legend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.one) {
            ForEach(SessionStatus.all, id: \.self) { status in
                HStack(spacing: Space.two) {
                    StatusDot(status: status, size: 7)
                    Text(status.label)
                        .font(Typeface.body(11))
                        .foregroundStyle(Palette.neutral(700))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.four)
        .padding(.vertical, Space.three)
    }
}
