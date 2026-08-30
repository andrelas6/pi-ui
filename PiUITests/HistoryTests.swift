import Foundation
import Testing

@testable import PiUI

struct HistoryTests {
    private func stored(_ json: String) throws -> [JSONValue] {
        try #require(JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)).array)
    }

    @Test func replaysAPlainExchange() throws {
        let messages = History.messages(from: try stored("""
        [
          {"role":"user","content":[{"type":"text","text":"hello"}]},
          {"role":"assistant","content":[{"type":"text","text":"hi there"}]}
        ]
        """))

        #expect(messages.count == 2)
        #expect(messages[0].kind == .user)
        #expect(messages[0].text == "hello")
        #expect(messages[1].kind == .assistant)
        #expect(messages[1].text == "hi there")
        let everythingDone = messages.allSatisfy(\.done)
        #expect(everythingDone)
    }

    @Test func rebuildsToolCardsWithTheirResults() throws {
        let messages = History.messages(from: try stored("""
        [
          {"role":"user","content":[{"type":"text","text":"read it"}]},
          {"role":"assistant","content":[
            {"type":"thinking","thinking":"hmm"},
            {"type":"toolCall","id":"call_1","name":"read","arguments":{"path":"notes.txt"}}
          ]},
          {"role":"toolResult","toolCallId":"call_1","toolName":"read","isError":false,
           "content":[{"type":"text","text":"file body"}]},
          {"role":"assistant","content":[{"type":"text","text":"it says file body"}]}
        ]
        """))

        #expect(messages.count == 3)
        #expect(messages[1].kind == .tool)
        #expect(messages[1].id == "call_1")
        #expect(messages[1].tool?.name == "read")
        #expect(messages[1].tool?.preview == "notes.txt")
        #expect(messages[1].tool?.output == "file body")
        #expect(messages[1].tool?.failed == false)
        #expect(messages[2].text == "it says file body")
    }

    @Test func keepsAFailedToolFailed() throws {
        let messages = History.messages(from: try stored("""
        [
          {"role":"assistant","content":[
            {"type":"toolCall","id":"call_1","name":"bash","arguments":{"command":"nope"}}
          ]},
          {"role":"toolResult","toolCallId":"call_1","isError":true,
           "content":[{"type":"text","text":"not found"}]}
        ]
        """))

        #expect(messages[0].tool?.failed == true)
        #expect(messages[0].tool?.output == "not found")
    }

    /// Thinking blocks are not part of the transcript.
    @Test func dropsThinkingBlocks() throws {
        let messages = History.messages(from: try stored("""
        [{"role":"assistant","content":[
          {"type":"thinking","thinking":"private reasoning"},
          {"type":"text","text":"the answer"}
        ]}]
        """))

        #expect(messages.count == 1)
        #expect(messages[0].text == "the answer")
    }

    @Test func acceptsPlainStringContent() throws {
        let messages = History.messages(from: try stored("""
        [{"role":"user","content":"just a string"}]
        """))

        #expect(messages.count == 1)
        #expect(messages[0].text == "just a string")
    }

    @Test func ignoresAResultWithNoMatchingCall() throws {
        let messages = History.messages(from: try stored("""
        [{"role":"toolResult","toolCallId":"ghost","content":[{"type":"text","text":"x"}]}]
        """))

        #expect(messages.isEmpty)
    }

    @Test func skipsEmptyAndUnknownRoles() throws {
        let messages = History.messages(from: try stored("""
        [
          {"role":"user","content":[]},
          {"role":"system","content":[{"type":"text","text":"ignored"}]},
          {"role":"user","content":[{"type":"text","text":"kept"}]}
        ]
        """))

        #expect(messages.count == 1)
        #expect(messages[0].text == "kept")
    }

    @Test func handlesAnEmptyHistory() {
        #expect(History.messages(from: []).isEmpty)
    }

    @Test func keepsSeveralToolCallsApart() throws {
        let messages = History.messages(from: try stored("""
        [
          {"role":"assistant","content":[
            {"type":"toolCall","id":"a","name":"bash","arguments":{"command":"ls"}},
            {"type":"toolCall","id":"b","name":"read","arguments":{"path":"x.txt"}}
          ]},
          {"role":"toolResult","toolCallId":"b","content":[{"type":"text","text":"body"}]},
          {"role":"toolResult","toolCallId":"a","content":[{"type":"text","text":"listing"}]}
        ]
        """))

        #expect(messages[0].tool?.output == "listing")
        #expect(messages[1].tool?.output == "body")
    }
}
