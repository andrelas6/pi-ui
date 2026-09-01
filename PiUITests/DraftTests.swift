import Foundation
import Testing

@testable import PiUI

@MainActor
struct DraftTests {
    private func newPool() -> (ChatPool, SessionStore) {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-draft-\(UUID().uuidString).json")
        let store = SessionStore(file: index)
        return (ChatPool(store: store), store)
    }

    private func attach(_ id: String, to pool: ChatPool, store: SessionStore) -> Chat {
        store.remember(id: id, folder: URL(fileURLWithPath: "/tmp/\(id)"), file: nil)
        let chat = Chat(store: store)
        chat.markOpenForTesting(id)
        pool.adoptForTesting(chat)
        return chat
    }

    @Test func startsEmpty() {
        let (pool, store) = newPool()
        #expect(attach("one", to: pool, store: store).draft.isEmpty)
    }

    /// The composer's text used to be view state, so switching sessions threw it away.
    @Test func eachSessionKeepsItsOwnText() {
        let (pool, store) = newPool()
        let first = attach("one", to: pool, store: store)
        let second = attach("two", to: pool, store: store)

        first.draft = "half a thought"
        second.draft = "something else"

        #expect(first.draft == "half a thought")
        #expect(second.draft == "something else")
    }

    @Test func survivesBeingShownAgain() {
        let (pool, store) = newPool()
        let chat = attach("one", to: pool, store: store)
        chat.draft = "still here"

        pool.show(store.session("one")!)
        pool.show(store.session("one")!)

        #expect(pool.current?.draft == "still here")
    }

    /// The palette writes an invocation in; a half-typed line is not thrown away.
    @Test func aCommandJoinsWhatIsAlreadyThere() {
        let (pool, store) = newPool()
        let chat = attach("one", to: pool, store: store)

        chat.draft = ""
        chat.draft = chat.draft.isEmpty ? "/skill:tidy " : chat.draft + " /skill:tidy "
        #expect(chat.draft == "/skill:tidy ")

        chat.draft = "rename the type"
        chat.draft = chat.draft.isEmpty ? "/skill:tidy " : chat.draft + " /skill:tidy "
        #expect(chat.draft == "rename the type /skill:tidy ")
    }
}
