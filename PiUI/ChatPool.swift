import AppKit
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
    private(set) var finishedUnseen: Set<String> = []

    init(store: SessionStore) {
        self.store = store
    }

    func startNew(in folder: URL) {
        let chat = make()
        current = chat
        chat.open(folder, thenType: true)
    }

    func show(_ saved: SavedSession, thenType: Bool = false) {
        markSeen(saved.id)

        if let running = chat(for: saved.id) {
            current = running
            if thenType { running.askToType() }
            return
        }

        let chat = make()
        current = chat
        chat.open(saved.folder, sessionId: saved.id, thenType: thenType)
    }

    private func make() -> Chat {
        let chat = Chat(store: store)
        chat.onSettled = { [weak self, weak chat] in
            guard let self, let chat else { return }
            self.noteFinished(chat)
        }
        chats.append(chat)
        return chat
    }

    /// A session that finishes while you are reading another one is the whole point
    /// of running them in the background, so say so rather than waiting to be found.
    private func noteFinished(_ chat: Chat) {
        guard chat !== current, let id = chat.openSessionId else { return }
        finishedUnseen.insert(id)
        showBadge()
        if !NSApp.isActive {
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    func markSeen(_ id: String) {
        guard finishedUnseen.remove(id) != nil else { return }
        showBadge()
    }

    func isFinishedUnseen(_ id: String) -> Bool {
        finishedUnseen.contains(id)
    }

    private func showBadge() {
        NSApp.dockTile.badgeLabel = finishedUnseen.isEmpty ? nil : "\(finishedUnseen.count)"
    }

    func adoptForTesting(_ chat: Chat) {
        chat.onSettled = { [weak self, weak chat] in
            guard let self, let chat else { return }
            self.noteFinished(chat)
        }
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
        markSeen(id)
        guard let chat = chat(for: id) else { return }
        chat.close()
        chats.removeAll { $0 === chat }
        if current === chat { current = chats.last }
    }

    func closeAll() {
        chats.forEach { $0.close() }
        chats = []
        current = nil
        finishedUnseen = []
        showBadge()
    }
}
