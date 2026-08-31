import SwiftUI
import Testing

@testable import PiUI

struct SessionStatusTests {
    /// Only the ochre state steps outside the steel palette, and only for needs-input.
    @Test func needsInputIsTheOneOchreSignal() {
        #expect(SessionStatus.needsInput.color == Palette.ochre)
        #expect(SessionStatus.working.color == Palette.accent)
        #expect(SessionStatus.done.color == Palette.neutral(400))
    }

    @Test func onlyTheLiveStatesPulse() {
        #expect(SessionStatus.done.beat == nil)
        #expect(SessionStatus.working.beat == 2)
        #expect(SessionStatus.needsInput.beat == 1.6)
    }

    /// A still dot must stay at full strength; fading a done session would read as busy.
    @Test func doneDoesNotFade() {
        #expect(SessionStatus.done.faded == 1)
        #expect(SessionStatus.working.faded == 0.28)
        #expect(SessionStatus.needsInput.faded == 0.3)
    }

    @Test func needsInputBeatsFasterThanWorking() {
        let working = SessionStatus.working.beat ?? 0
        let needsInput = SessionStatus.needsInput.beat ?? 0
        #expect(needsInput < working)
    }

    @Test func namesEveryStateForTheLegend() {
        #expect(SessionStatus.all.count == 3)
        for status in SessionStatus.all {
            #expect(status.label.isEmpty == false)
        }
    }
}

@MainActor
struct RailStatusTests {
    private func newPool() -> (ChatPool, SessionStore) {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-rail-\(UUID().uuidString).json")
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

    /// The rail reads these three off the pool, and waiting has to win over working —
    /// a session that stopped to ask is not busy, it is blocked on you.
    @Test func waitingOutranksWorking() throws {
        let (pool, store) = newPool()
        let chat = attach("one", to: pool, store: store)

        #expect(pool.isWaiting("one") == false)

        chat.handle(try JSONDecoder().decode(JSONValue.self, from: Data(#"""
        {"type":"extension_ui_request","id":"u1","method":"confirm","title":"bash","message":"ls"}
        """#.utf8)))

        #expect(pool.isWaiting("one") == true)
    }

    @Test func aSessionWithNoProcessReadsAsDone() {
        let (pool, store) = newPool()
        store.remember(id: "cold", folder: URL(fileURLWithPath: "/tmp/cold"), file: nil)

        #expect(pool.isWaiting("cold") == false)
        #expect(pool.isBusy("cold") == false)
    }
}
