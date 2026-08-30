import Foundation
import Testing

@testable import PiUI

@MainActor
struct ChatTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func appendsStreamedText() throws {
        let chat = Chat()
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"hel"}}"#))
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"lo"}}"#))
        #expect(chat.transcript == "hello")
    }

    @Test func ignoresThinkingDeltas() throws {
        let chat = Chat()
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"thinking_delta","delta":"hmm"}}"#))
        #expect(chat.transcript.isEmpty)
    }

    @Test func marksToolCalls() throws {
        let chat = Chat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolName":"bash","toolCallId":"c1"}"#))
        #expect(chat.transcript.contains("[bash]"))
    }

    @Test func showsProviderErrors() throws {
        let chat = Chat()
        let failure = #"{"type":"message_end","message":{"role":"assistant","stopReason":"error","errorMessage":"402: {\"message\":\"This request requires more credits\"}"}}"#
        chat.handle(try event(failure))
        #expect(chat.problem == "402: This request requires more credits")
    }

    @Test func ignoresHealthyMessageEnd() throws {
        let chat = Chat()
        chat.handle(try event(#"{"type":"message_end","message":{"role":"assistant","stopReason":"stop"}}"#))
        #expect(chat.problem == nil)
    }

    @Test func fallsBackWhenTheErrorHasNoSentence() {
        #expect(Chat.readable("something broke") == "something broke")
        #expect(Chat.readable(nil) == "The model returned an error.")
    }
}
