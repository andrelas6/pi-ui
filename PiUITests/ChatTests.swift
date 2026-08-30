import Foundation
import Testing

@testable import PiUI

@MainActor
struct ChatTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-chat-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    private func stream(_ chat: Chat, _ parts: [String]) throws {
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_start"}}"#))
        for part in parts {
            chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"\#(part)"}}"#))
        }
    }

    @Test func buildsOneMessageFromManyDeltas() throws {
        let chat = newChat()
        try stream(chat, ["hel", "lo ", "there"])

        #expect(chat.messages.count == 1)
        #expect(chat.messages[0].kind == .assistant)
        #expect(chat.messages[0].text == "hello there")
    }

    @Test func marksAMessageDoneAtTextEnd() throws {
        let chat = newChat()
        try stream(chat, ["hi"])
        #expect(chat.messages[0].done == false)

        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_end"}}"#))
        #expect(chat.messages[0].done == true)
    }

    @Test func startsAFreshMessageForEachTextBlock() throws {
        let chat = newChat()
        try stream(chat, ["first"])
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_end"}}"#))
        try stream(chat, ["second"])

        #expect(chat.messages.count == 2)
        #expect(chat.messages[0].text == "first")
        #expect(chat.messages[1].text == "second")
    }

    @Test func ignoresThinkingDeltas() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"thinking_delta","delta":"hmm"}}"#))
        #expect(chat.messages.isEmpty)
    }

    @Test func addsAToolMarker() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolName":"bash","toolCallId":"c1"}"#))

        #expect(chat.messages.count == 1)
        #expect(chat.messages[0].kind == .tool)
        #expect(chat.messages[0].text == "bash")
    }

    @Test func closesAnOpenMessageBeforeAToolRuns() throws {
        let chat = newChat()
        try stream(chat, ["thinking about it"])
        chat.handle(try event(#"{"type":"tool_execution_start","toolName":"read","toolCallId":"c1"}"#))

        #expect(chat.messages[0].done == true)
        #expect(chat.messages[1].kind == .tool)
    }

    @Test func showsProviderErrors() throws {
        let chat = newChat()
        let failure = #"{"type":"message_end","message":{"role":"assistant","stopReason":"error","errorMessage":"402: {\"message\":\"This request requires more credits\"}"}}"#
        chat.handle(try event(failure))
        #expect(chat.problem == "402: This request requires more credits")
    }

    @Test func ignoresHealthyMessageEnd() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"message_end","message":{"role":"assistant","stopReason":"stop"}}"#))
        #expect(chat.problem == nil)
    }

    @Test func settlingClosesAnUnfinishedMessage() throws {
        let chat = newChat()
        try stream(chat, ["cut off"])
        chat.handle(try event(#"{"type":"agent_settled"}"#))

        #expect(chat.messages[0].done == true)
        #expect(chat.isStreaming == false)
    }

    @Test func fallsBackWhenTheErrorHasNoSentence() {
        #expect(Chat.readable("something broke") == "something broke")
        #expect(Chat.readable(nil) == "The model returned an error.")
    }
}
