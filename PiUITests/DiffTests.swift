import Foundation
import Testing

@testable import PiUI

@MainActor
struct DiffTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-diff-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    /// pi computes the diff itself and hands it over in the result details.
    @Test func keepsTheDiffFromAnEdit() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"edit","args":{"path":"notes.txt"}}"#))
        chat.handle(try event(#"""
        {"type":"tool_execution_end","toolCallId":"c1","toolName":"edit","isError":false,
         "result":{"content":[{"type":"text","text":"Replaced 1 block."}],
                   "details":{"diff":" 1 alpha\n-2 beta\n+2 BETA\n 3 gamma","firstChangedLine":2}}}
        """#))

        #expect(chat.messages[0].tool?.diff == " 1 alpha\n-2 beta\n+2 BETA\n 3 gamma")
        #expect(chat.messages[0].tool?.output == "Replaced 1 block.")
    }

    @Test func leavesTheDiffEmptyForToolsThatHaveNone() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"bash","args":{"command":"ls"}}"#))
        chat.handle(try event(#"""
        {"type":"tool_execution_end","toolCallId":"c1","toolName":"bash","isError":false,
         "result":{"content":[{"type":"text","text":"a.txt"}]}}
        """#))

        #expect(chat.messages[0].tool?.diff == "")
        #expect(chat.messages[0].tool?.output == "a.txt")
    }

    @Test func survivesDetailsWithoutADiff() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"tool_execution_start","toolCallId":"c1","toolName":"edit","args":{}}"#))
        chat.handle(try event(#"""
        {"type":"tool_execution_end","toolCallId":"c1","isError":false,
         "result":{"content":[],"details":{"truncation":null}}}
        """#))

        #expect(chat.messages[0].tool?.diff == "")
    }

    @Test func restoresADiffFromHistory() throws {
        let stored = try #require(try event(#"""
        [
          {"role":"assistant","content":[
            {"type":"toolCall","id":"c1","name":"edit","arguments":{"path":"notes.txt"}}
          ]},
          {"role":"toolResult","toolCallId":"c1","isError":false,
           "content":[{"type":"text","text":"done"}],
           "details":{"diff":"-1 old\n+1 new"}}
        ]
        """#).array)

        let messages = History.messages(from: stored)
        #expect(messages[0].tool?.diff == "-1 old\n+1 new")
    }

    @Test func historyWithoutDetailsHasNoDiff() throws {
        let stored = try #require(try event(#"""
        [
          {"role":"assistant","content":[
            {"type":"toolCall","id":"c1","name":"read","arguments":{"path":"a.txt"}}
          ]},
          {"role":"toolResult","toolCallId":"c1","content":[{"type":"text","text":"body"}]}
        ]
        """#).array)

        let messages = History.messages(from: stored)
        #expect(messages[0].tool?.diff == "")
        #expect(messages[0].tool?.output == "body")
    }
}
