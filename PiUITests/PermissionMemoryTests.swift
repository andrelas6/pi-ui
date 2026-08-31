import Foundation
import Testing

@testable import PiUI

@MainActor
struct PermissionMemoryTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-perm-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    private func askFor(_ tool: String) -> String {
        #"{"type":"extension_ui_request","id":"u1","method":"confirm","title":"\#(tool)","message":"ls -la"}"#
    }

    @Test func asksTheFirstTime() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))

        #expect(chat.ask?.title == "bash")
        #expect(chat.alwaysAllowed.isEmpty)
    }

    @Test func stopsAskingOnceToldAlways() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        let ask = try #require(chat.ask)

        chat.alwaysAllow(ask)
        #expect(chat.ask == nil)
        #expect(chat.alwaysAllowed.contains("bash"))

        chat.handle(try event(askFor("bash")))
        #expect(chat.ask == nil)
    }

    /// Remembering bash must not quietly permit edit.
    @Test func remembersOneToolAtATime() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        chat.alwaysAllow(try #require(chat.ask))

        chat.handle(try event(askFor("edit")))
        #expect(chat.ask?.title == "edit")
    }

    @Test func aPlainAllowIsNotRemembered() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        chat.answer(try #require(chat.ask), confirmed: true)

        chat.handle(try event(askFor("bash")))
        #expect(chat.ask?.title == "bash")
    }

    @Test func denyingIsNeverRemembered() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        chat.answer(try #require(chat.ask), confirmed: false)

        #expect(chat.alwaysAllowed.isEmpty)
        chat.handle(try event(askFor("bash")))
        #expect(chat.ask?.title == "bash")
    }

    /// Only a yes/no question can be answered from memory.
    @Test func neverAnswersOtherDialogsFromMemory() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        chat.alwaysAllow(try #require(chat.ask))

        chat.handle(try event(#"{"type":"extension_ui_request","id":"u2","method":"input","title":"bash"}"#))
        #expect(chat.ask?.method == .input)
    }

    @Test func forgetsWhenTheSessionIsCleared() throws {
        let chat = newChat()
        chat.handle(try event(askFor("bash")))
        chat.alwaysAllow(try #require(chat.ask))

        chat.forgetAllowances()
        #expect(chat.alwaysAllowed.isEmpty)

        chat.handle(try event(askFor("bash")))
        #expect(chat.ask?.title == "bash")
    }
}
