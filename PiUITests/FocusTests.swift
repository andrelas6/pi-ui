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

    /// Jumping to the session already open still hands over the cursor, even though
    /// there is nothing to load.
    @Test func asksWhenJumpingToTheOpenSession() {
        let chat = newChat()
        let saved = SavedSession(
            id: "open-one",
            name: nil,
            folder: URL(fileURLWithPath: "/tmp/a"),
            file: nil,
            everSaved: false,
            createdAt: .now,
            lastOpenedAt: .now
        )
        chat.pretendOpenForTesting(saved.id)

        chat.reopen(saved, thenType: true)
        #expect(chat.typingRequests == 1)
    }

    @Test func staysQuietWhenNotAskedTo() {
        let chat = newChat()
        let saved = SavedSession(
            id: "open-one",
            name: nil,
            folder: URL(fileURLWithPath: "/tmp/a"),
            file: nil,
            everSaved: false,
            createdAt: .now,
            lastOpenedAt: .now
        )
        chat.pretendOpenForTesting(saved.id)

        chat.reopen(saved)
        #expect(chat.typingRequests == 0)
    }
}
