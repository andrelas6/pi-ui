import Foundation
import Testing

@testable import PiUI

@MainActor
struct FocusTests {
    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-focus-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    private func newPool() -> (ChatPool, SessionStore) {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-focus-pool-\(UUID().uuidString).json")
        let store = SessionStore(file: index)
        return (ChatPool(store: store), store)
    }

    @Test func startsWithNoRequest() {
        #expect(newChat().typingRequests == 0)
    }

    @Test func eachAskIsItsOwnRequest() {
        let chat = newChat()
        chat.askToType()
        chat.askToType()

        // Asking twice has to register twice, or a second jump to the same session
        // would not move the cursor.
        #expect(chat.typingRequests == 2)
    }

    /// Jumping to a session already on screen still hands over the cursor, which is
    /// exactly when someone is reading it and wants to reply.
    @Test func asksWhenShowingTheSessionAlreadyOnScreen() {
        let (pool, store) = newPool()
        store.remember(id: "one", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        let saved = try? #require(store.session("one"))
        guard let saved else { return }

        let chat = Chat(store: store)
        chat.markOpenForTesting(saved.id)
        pool.adoptForTesting(chat)

        pool.show(saved, thenType: true)
        #expect(chat.typingRequests == 1)
        #expect(pool.current === chat)
    }

    @Test func staysQuietWhenNotAskedTo() {
        let (pool, store) = newPool()
        store.remember(id: "one", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        guard let saved = store.session("one") else { return }

        let chat = Chat(store: store)
        chat.markOpenForTesting(saved.id)
        pool.adoptForTesting(chat)

        pool.show(saved)
        #expect(chat.typingRequests == 0)
    }
}
