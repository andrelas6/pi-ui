import SwiftUI

struct ContentView: View {
    let shortcuts: Shortcuts

    @State private var store = SessionStore()
    @State private var pool: ChatPool?
    @State private var keys = KeyMonitor()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, pool: pool, open: show, start: start)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            if let chat = pool?.current {
                ConversationView(chat: chat)
            } else {
                ContentUnavailableView(
                    "No session open",
                    systemImage: "sidebar.left",
                    description: Text("Press ⌃T, or use the + button, to pick a folder.")
                )
            }
        }
        .task {
            let pool = ChatPool(store: store)
            self.pool = pool
            keys.start(
                newSession: { startNewSession(with: pool) },
                jump: { number in
                    guard let session = store.session(at: number) else { return }
                    pool.show(session, thenType: true)
                }
            )
        }
        .onChange(of: shortcuts.newSessionCount) { _, _ in
            guard let pool else { return }
            startNewSession(with: pool)
        }
        .onChange(of: shortcuts.jumpTo) { _, number in
            guard let number else { return }
            shortcuts.jumpTo = nil
            guard let session = store.session(at: number) else { return }
            pool?.show(session, thenType: true)
        }
        .sheet(item: sheetBinding) { ask in
            AskSheet(
                ask: ask,
                confirm: { pool?.current?.answer(ask, confirmed: $0) },
                remember: { pool?.current?.alwaysAllow(ask) },
                submit: { pool?.current?.answer(ask, value: $0) },
                cancel: { pool?.current?.dismiss(ask) }
            )
        }
    }

    private var sheetBinding: Binding<Ask?> {
        Binding(get: { pool?.current?.ask }, set: { _ in })
    }

    private func start(_ folder: URL) {
        pool?.startNew(in: folder)
    }

    private func startNewSession(with pool: ChatPool) {
        guard let folder = FolderPicker.pick() else { return }
        pool.startNew(in: folder)
    }

    private func show(_ saved: SavedSession) {
        pool?.show(saved)
    }
}
