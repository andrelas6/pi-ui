import SwiftUI

struct ContentView: View {
    let shortcuts: Shortcuts

    @State private var store = SessionStore()
    @State private var chat: Chat?

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
                    description: Text("Pick a folder with the + button.")
                )
            }
        }
        .task {
            chat = Chat(store: store)
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
        guard let folder = FolderPicker.pick() else { return }
        chat?.open(folder)
    }

    private func open(_ saved: SavedSession) {
        chat?.reopen(saved)
    }
}
