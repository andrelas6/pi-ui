import Foundation
import Testing

@testable import PiUI

@MainActor
struct ToolCardTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-tool-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    @Test func opensACardWhenAToolStarts() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"bash","args":{"command":"ls -la"}}"#))

        #expect(chat.messages.count == 1)
        let message = chat.messages[0]
        #expect(message.kind == .tool)
        #expect(message.id == "c1")
        #expect(message.done == false)
        #expect(message.tool?.name == "bash")
        #expect(message.tool?.preview == "ls -la")
        #expect(message.tool?.arguments.contains("ls -la") == true)
    }

    @Test func replacesOutputOnEachUpdate() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"bash","args":{"command":"x"}}"#))
        chat.handle(try event(#"{"type":"tool_execution_update","toolCallId":"c1","partialResult":{"content":[{"type":"text","text":"line 1\n"}]}}"#))
        #expect(chat.messages[0].tool?.output == "line 1\n")

        // partialResult is cumulative, not a delta.
        chat.handle(try event(#"{"type":"tool_execution_update","toolCallId":"c1","partialResult":{"content":[{"type":"text","text":"line 1\nline 2\n"}]}}"#))
        #expect(chat.messages[0].tool?.output == "line 1\nline 2\n")
    }

    @Test func closesTheCardOnEnd() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"read","args":{"path":"notes.txt"}}"#))
        chat.handle(try event(#"{"type":"tool_execution_end","toolCallId":"c1","toolName":"read","isError":false,"result":{"content":[{"type":"text","text":"first line\n"}]}}"#))

        #expect(chat.messages[0].done == true)
        #expect(chat.messages[0].tool?.output == "first line\n")
        #expect(chat.messages[0].tool?.failed == false)
    }

    @Test func marksAFailedTool() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"bash","args":{"command":"nope"}}"#))
        chat.handle(try event(#"{"type":"tool_execution_end","toolCallId":"c1","toolName":"bash","isError":true,"result":{"content":[{"type":"text","text":"command not found"}]}}"#))

        #expect(chat.messages[0].tool?.failed == true)
        #expect(chat.messages[0].tool?.output == "command not found")
    }

    /// Tools run concurrently, so results arrive in a different order than the starts.
    @Test func matchesResultsToTheRightCard() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"a","toolName":"bash","args":{"command":"ls"}}"#))
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"b","toolName":"read","args":{"path":"notes.txt"}}"#))

        chat.handle(try event(#"{"type":"tool_execution_end","toolCallId":"b","isError":false,"result":{"content":[{"type":"text","text":"file body"}]}}"#))
        chat.handle(try event(#"{"type":"tool_execution_end","toolCallId":"a","isError":false,"result":{"content":[{"type":"text","text":"listing"}]}}"#))

        #expect(chat.messages[0].tool?.output == "listing")
        #expect(chat.messages[1].tool?.output == "file body")
    }

    @Test func ignoresEventsForAnUnknownCall() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_end","toolCallId":"ghost","isError":false,"result":{"content":[]}}"#))
        #expect(chat.messages.isEmpty)
    }

    @Test func joinsEveryTextBlock() throws {
        let result = try event(#"{"content":[{"type":"text","text":"one "},{"type":"text","text":"two"}]}"#)
        #expect(result.contentText == "one two")
    }

    @Test func survivesAResultWithNoContent() throws {
        let result = try event(#"{"details":{}}"#)
        #expect(result.contentText == "")
    }

    @Test func picksThePreviewPerTool() throws {
        #expect(ChatMessage.ToolCall.preview(of: try event(#"{"command":"ls -la"}"#)) == "ls -la")
        #expect(ChatMessage.ToolCall.preview(of: try event(#"{"path":"a/b.txt"}"#)) == "a/b.txt")
        #expect(ChatMessage.ToolCall.preview(of: try event(#"{"pattern":"todo"}"#)) == "todo")
        #expect(ChatMessage.ToolCall.preview(of: try event(#"{"other":1}"#)) == "")
        #expect(ChatMessage.ToolCall.preview(of: nil) == "")
    }

    @Test func prettyPrintsArgumentsForDisplay() throws {
        let args = try event(#"{"path":"notes.txt","edits":[{"oldText":"a"}]}"#)
        let pretty = args.prettyText
        #expect(pretty.contains("\n"))
        #expect(pretty.contains("\"path\""))
    }

    @Test func closesAnOpenTextMessageFirst() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_start"}}"#))
        chat.handle(try event(#"{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"about to run"}}"#))
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"bash","args":{"command":"ls"}}"#))

        #expect(chat.messages[0].done == true)
        #expect(chat.messages[1].kind == .tool)
    }
}
