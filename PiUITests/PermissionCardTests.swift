import Foundation
import Testing

@testable import PiUI

@MainActor
struct PermissionCardTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-card-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    private func confirm(_ tool: String, id: String = "u1") -> String {
        #"{"type":"extension_ui_request","id":"\#(id)","method":"confirm","title":"\#(tool)","message":"rm -rf build"}"#
    }

    @Test func aConfirmBecomesACardInTheLog() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))

        #expect(chat.messages.count == 1)
        let card = chat.messages[0]
        #expect(card.kind == .permission)
        #expect(card.id == "u1")
        #expect(card.done == false)
        #expect(card.request?.tool == "bash")
        #expect(card.request?.detail == "rm -rf build")
        #expect(card.request?.answer == "")
    }

    /// The card is the surface, but `ask` still has to be set — the rail's pulsing dot
    /// and the title bar's count both read it.
    @Test func stillCountsAsWaiting() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))
        #expect(chat.ask?.id == "u1")
    }

    /// select, input and editor are not drawn in the log and keep their sheet.
    @Test func otherDialogsDoNotBecomeCards() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"extension_ui_request","id":"u2","method":"input","title":"Name"}"#))

        #expect(chat.messages.isEmpty)
        #expect(chat.ask?.method == .input)
    }

    @Test func answeringSettlesTheCard() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))

        chat.answerRequest(id: "u1", choice: ChatMessage.Request.allow)

        #expect(chat.messages[0].done)
        #expect(chat.messages[0].request?.answer == "allow")
        #expect(chat.ask == nil)
    }

    @Test func alwaysAllowIsRememberedFromTheCard() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))

        chat.answerRequest(id: "u1", choice: ChatMessage.Request.always)

        #expect(chat.alwaysAllowed.contains("bash"))
        #expect(chat.messages[0].request?.answer == "always")

        // A remembered tool never reaches the log again.
        chat.handle(try event(confirm("bash", id: "u2")))
        #expect(chat.messages.count == 1)
    }

    @Test func denyingIsRecordedAndNotRemembered() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))

        chat.answerRequest(id: "u1", choice: ChatMessage.Request.deny)

        #expect(chat.messages[0].request?.answer == "deny")
        #expect(chat.alwaysAllowed.isEmpty)
    }

    /// A stale click from the page must not answer a question that moved on.
    @Test func ignoresAnAnswerForAnotherRequest() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))

        chat.answerRequest(id: "somewhere-else", choice: ChatMessage.Request.allow)

        #expect(chat.messages[0].done == false)
        #expect(chat.ask?.id == "u1")
    }

    /// What Cmd-Y and Cmd-R call. They must do nothing at all when the log is not
    /// asking, or the keys would be swallowed from whatever has focus.
    @Test func thereIsNothingToAnswerWhenNobodyAsked() {
        let chat = newChat()
        #expect(chat.ask == nil)
        chat.answerRequest(id: "u1", choice: ChatMessage.Request.allow)
        #expect(chat.messages.isEmpty)
    }

    @Test func theKeysAnswerTheSameWayTheButtonsDo() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))
        let pending = try #require(chat.ask)

        chat.answerRequest(id: pending.id, choice: ChatMessage.Request.deny)

        #expect(chat.messages[0].request?.answer == "deny")
        #expect(chat.ask == nil)
    }

    /// Otherwise a card left behind by an aborted turn keeps offering buttons that
    /// answer nothing.
    @Test func settlingTheTurnClosesAnUnansweredCard() throws {
        let chat = newChat()
        chat.handle(try event(confirm("bash")))
        chat.handle(try event(#"{"type":"agent_settled"}"#))

        #expect(chat.messages[0].done)
        #expect(chat.messages[0].request?.answer == "")
    }
}
