import SwiftUI

struct ContentView: View {
    let shortcuts: Shortcuts

    @State private var store = SessionStore()
    @State private var chat: Chat?
    @State private var keys = KeyMonitor()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, chat: chat, open: open, start: start)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            if let chat {
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
            let chat = Chat(store: store)
            self.chat = chat
            keys.start(
                newSession: { startNewSession(with: chat) },
                jump: { number in
                    guard let session = store.session(at: number) else { return }
                    chat.reopen(session, thenType: true)
                }
            )
        }
        .onChange(of: shortcuts.newSessionCount) { _, _ in
            startNewSession()
        }
        .onChange(of: shortcuts.jumpTo) { _, number in
            guard let number else { return }
            shortcuts.jumpTo = nil
            guard let session = store.session(at: number) else { return }
            chat?.reopen(session)
        }
        .sheet(item: sheetBinding) { ask in
            AskSheet(
                ask: ask,
                confirm: { chat?.answer(ask, confirmed: $0) },
                submit: { chat?.answer(ask, value: $0) },
                cancel: { chat?.dismiss(ask) }
            )
        }
    }

    private var sheetBinding: Binding<Ask?> {
        Binding(get: { chat?.ask }, set: { _ in })
    }

    private func start(_ folder: URL) {
        chat?.open(folder)
    }

    private func startNewSession() {
        guard let chat else { return }
        startNewSession(with: chat)
    }

    private func startNewSession(with chat: Chat) {
        guard let folder = FolderPicker.pick() else { return }
        chat.open(folder, thenType: true)
    }

    private func open(_ saved: SavedSession) {
        chat?.reopen(saved)
    }
}
