import Foundation
import Testing

@testable import PiUI

@MainActor
struct AskTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-ask-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    @Test func readsAConfirmRequest() throws {
        let ask = try #require(Ask(try event(#"""
        {"type":"extension_ui_request","id":"u1","method":"confirm","title":"Allow bash?","message":"echo hello"}
        """#)))

        #expect(ask.id == "u1")
        #expect(ask.method == .confirm)
        #expect(ask.title == "Allow bash?")
        #expect(ask.message == "echo hello")
    }

    @Test func readsASelectRequest() throws {
        let ask = try #require(Ask(try event(#"""
        {"type":"extension_ui_request","id":"u2","method":"select","title":"Pick","options":["Allow","Block"]}
        """#)))

        #expect(ask.method == .select)
        #expect(ask.options == ["Allow", "Block"])
    }

    @Test func readsAnEditorRequestWithPrefill() throws {
        let ask = try #require(Ask(try event(#"""
        {"type":"extension_ui_request","id":"u3","method":"editor","title":"Edit","prefill":"line one"}
        """#)))

        #expect(ask.method == .editor)
        #expect(ask.prefill == "line one")
    }

    /// Fire-and-forget methods expect no reply, so they must not become a dialog.
    @Test func refusesFireAndForgetMethods() throws {
        for method in ["notify", "setStatus", "setWidget", "setTitle", "set_editor_text"] {
            let value = try event(#"{"type":"extension_ui_request","id":"x","method":"\#(method)"}"#)
            #expect(Ask(value) == nil)
        }
    }

    @Test func refusesARequestWithNoId() throws {
        #expect(Ask(try event(#"{"type":"extension_ui_request","method":"confirm"}"#)) == nil)
    }

    @Test func raisesAnAskWhenAConfirmArrives() throws {
        let chat = newChat()
        chat.handle(try event(#"""
        {"type":"extension_ui_request","id":"u1","method":"confirm","title":"Allow bash?","message":"rm -rf /"}
        """#))

        #expect(chat.ask?.id == "u1")
        #expect(chat.ask?.method == .confirm)
    }

    @Test func showsNotifyAsANoticeRatherThanADialog() throws {
        let chat = newChat()
        chat.handle(try event(#"""
        {"type":"extension_ui_request","id":"u9","method":"notify","message":"Command blocked","notifyType":"warning"}
        """#))

        #expect(chat.notice == "Command blocked")
        #expect(chat.ask == nil)
    }

    @Test func ignoresStatusAndTitleRequests() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"extension_ui_request","id":"u8","method":"setTitle","title":"pi"}"#))
        chat.handle(try event(#"{"type":"extension_ui_request","id":"u7","method":"setStatus","statusKey":"k","statusText":"x"}"#))

        #expect(chat.ask == nil)
        #expect(chat.notice == nil)
    }

    @Test func clearsTheAskOnceAnswered() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"extension_ui_request","id":"u1","method":"confirm","title":"Allow?"}"#))
        let ask = try #require(chat.ask)

        chat.answer(ask, confirmed: false)
        #expect(chat.ask == nil)
    }

    @Test func clearsTheAskOnCancel() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"extension_ui_request","id":"u1","method":"input","title":"Name"}"#))
        let ask = try #require(chat.ask)

        chat.dismiss(ask)
        #expect(chat.ask == nil)
    }

    @Test func fallsBackToAReadableTitle() throws {
        let ask = try #require(Ask(try event(#"{"type":"extension_ui_request","id":"u1","method":"confirm"}"#)))
        #expect(ask.title == "pi is asking")
        #expect(ask.message.isEmpty)
    }
}
