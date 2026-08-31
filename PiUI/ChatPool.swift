import Foundation
import Observation

/// Holds one Chat per session so they keep running while you look at something else.
/// Switching changes which one is shown, not which one exists.
@MainActor
@Observable
final class ChatPool {
    private let store: SessionStore
    private(set) var chats: [Chat] = []
    private(set) var current: Chat?

    init(store: SessionStore) {
        self.store = store
    }

    func startNew(in folder: URL) {
        let chat = Chat(store: store)
        chats.append(chat)
        current = chat
        chat.open(folder, thenType: true)
    }

    func show(_ saved: SavedSession, thenType: Bool = false) {
        if let running = chat(for: saved.id) {
            current = running
            if thenType { running.askToType() }
            return
        }

        let chat = Chat(store: store)
        chats.append(chat)
        current = chat
        chat.open(saved.folder, sessionId: saved.id, thenType: thenType)
    }

    func adoptForTesting(_ chat: Chat) {
        chats.append(chat)
        current = chat
    }

    func chat(for id: String) -> Chat? {
        chats.first { $0.openSessionId == id }
    }

    func isBusy(_ id: String) -> Bool {
        chat(for: id)?.isStreaming ?? false
    }

    func isWaiting(_ id: String) -> Bool {
        chat(for: id)?.ask != nil
    }

    /// Somewhere else is asking for you, and it is not the session on screen.
    var elsewhereWaiting: Bool {
        chats.contains { $0.ask != nil && $0 !== current }
    }

    func drop(_ id: String) {
        guard let chat = chat(for: id) else { return }
        chat.close()
        chats.removeAll { $0 === chat }
        if current === chat { current = chats.last }
    }

    func closeAll() {
        chats.forEach { $0.close() }
        chats = []
        current = nil
    }
}
