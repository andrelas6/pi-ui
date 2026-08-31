import Foundation
import Testing

@testable import PiUI

@MainActor
struct ChatPoolTests {
    private func newPool() -> (ChatPool, SessionStore) {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-pool-\(UUID().uuidString).json")
        let store = SessionStore(file: index)
        return (ChatPool(store: store), store)
    }

    private func saved(_ id: String, in store: SessionStore) -> SavedSession {
        store.remember(id: id, folder: URL(fileURLWithPath: "/tmp/\(id)"), file: nil)
        return store.session(id)!
    }

    private func attach(_ id: String, to pool: ChatPool, store: SessionStore) -> Chat {
        let chat = Chat(store: store)
        chat.markOpenForTesting(id)
        pool.adoptForTesting(chat)
        return chat
    }

    @Test func startsEmpty() {
        let (pool, _) = newPool()
        #expect(pool.chats.isEmpty)
        #expect(pool.current == nil)
    }

    /// The whole point: showing another session must not tear down the one running.
    @Test func keepsTheOldSessionWhenShowingAnother() {
        let (pool, store) = newPool()
        let first = attach("one", to: pool, store: store)
        let second = attach("two", to: pool, store: store)

        pool.show(saved("one", in: store))

        #expect(pool.current === first)
        #expect(pool.chats.count == 2)
        #expect(pool.chat(for: "two") === second)
    }

    @Test func reusesTheChatForASessionItAlreadyHas() {
        let (pool, store) = newPool()
        let chat = attach("one", to: pool, store: store)

        pool.show(saved("one", in: store))
        pool.show(saved("one", in: store))

        #expect(pool.chats.count == 1)
        #expect(pool.current === chat)
    }

    @Test func findsAChatByItsSessionId() {
        let (pool, store) = newPool()
        let chat = attach("one", to: pool, store: store)

        #expect(pool.chat(for: "one") === chat)
        #expect(pool.chat(for: "nope") == nil)
    }

    @Test func dropsOneSessionAndKeepsTheRest() {
        let (pool, store) = newPool()
        _ = attach("one", to: pool, store: store)
        let second = attach("two", to: pool, store: store)

        pool.drop("one")

        #expect(pool.chats.count == 1)
        #expect(pool.chat(for: "one") == nil)
        #expect(pool.chat(for: "two") === second)
    }

    @Test func fallsBackToAnotherSessionWhenTheShownOneGoes() {
        let (pool, store) = newPool()
        let first = attach("one", to: pool, store: store)
        _ = attach("two", to: pool, store: store)

        pool.show(saved("two", in: store))
        pool.drop("two")

        #expect(pool.current === first)
    }

    @Test func closingEverythingLeavesNothing() {
        let (pool, store) = newPool()
        _ = attach("one", to: pool, store: store)
        _ = attach("two", to: pool, store: store)

        pool.closeAll()

        #expect(pool.chats.isEmpty)
        #expect(pool.current == nil)
    }

    @Test func flagsASessionThatFinishedWhileYouWereElsewhere() {
        let (pool, store) = newPool()
        let background = attach("one", to: pool, store: store)
        _ = attach("two", to: pool, store: store)
        pool.show(saved("two", in: store))

        background.onSettled?()

        #expect(pool.isFinishedUnseen("one") == true)
        #expect(pool.isFinishedUnseen("two") == false)
    }

    @Test func doesNotFlagTheSessionYouAreWatching() {
        let (pool, store) = newPool()
        let watched = attach("one", to: pool, store: store)
        pool.show(saved("one", in: store))

        watched.onSettled?()

        #expect(pool.isFinishedUnseen("one") == false)
    }

    @Test func clearsTheFlagOnceYouLook() {
        let (pool, store) = newPool()
        let background = attach("one", to: pool, store: store)
        _ = attach("two", to: pool, store: store)
        pool.show(saved("two", in: store))
        background.onSettled?()

        pool.show(saved("one", in: store))
        #expect(pool.isFinishedUnseen("one") == false)
    }

    /// A session waiting on an answer while you look elsewhere is the case the
    /// pulsing dot exists for, and it was unreachable with a single chat.
    @Test func noticesASessionWaitingInTheBackground() throws {
        let (pool, store) = newPool()
        let background = attach("one", to: pool, store: store)
        _ = attach("two", to: pool, store: store)

        pool.show(saved("two", in: store))
        #expect(pool.elsewhereWaiting == false)

        background.handle(try JSONDecoder().decode(JSONValue.self, from: Data(#"""
        {"type":"extension_ui_request","id":"u1","method":"confirm","title":"bash","message":"ls"}
        """#.utf8)))

        #expect(pool.isWaiting("one") == true)
        #expect(pool.isWaiting("two") == false)
        #expect(pool.elsewhereWaiting == true)
    }
}
