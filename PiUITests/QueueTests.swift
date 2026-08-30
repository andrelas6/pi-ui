import Foundation
import Testing

@testable import PiUI

@MainActor
struct QueueTests {
    private func event(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-queue-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    @Test func showsWhatIsQueued() throws {
        let chat = newChat()
        chat.handle(try event(#"""
        {"type":"queue_update","steering":["focus on errors"],"followUp":["then summarise"]}
        """#))

        #expect(chat.steering == ["focus on errors"])
        #expect(chat.followUps == ["then summarise"])
    }

    @Test func emptiesTheQueueWhenItDrains() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"queue_update","steering":["one"],"followUp":[]}"#))
        #expect(chat.steering == ["one"])

        chat.handle(try event(#"{"type":"queue_update","steering":[],"followUp":[]}"#))
        #expect(chat.steering.isEmpty)
    }

    @Test func clearsTheQueueWhenTheRunSettles() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"queue_update","steering":["one"],"followUp":["two"]}"#))
        chat.handle(try event(#"{"type":"agent_settled"}"#))

        #expect(chat.steering.isEmpty)
        #expect(chat.followUps.isEmpty)
        #expect(chat.isStreaming == false)
    }

    /// User bubbles come from pi, so a queued prompt lands when it is delivered.
    @Test func addsAUserMessageWhenPiEchoesIt() throws {
        let chat = newChat()
        chat.handle(try event(#"""
        {"type":"message_start","message":{"role":"user","content":[{"type":"text","text":"hello"}]}}
        """#))

        #expect(chat.messages.count == 1)
        #expect(chat.messages[0].kind == .user)
        #expect(chat.messages[0].text == "hello")
    }

    @Test func ignoresAssistantMessageStart() throws {
        let chat = newChat()
        chat.handle(try event(#"""
        {"type":"message_start","message":{"role":"assistant","content":[]}}
        """#))

        #expect(chat.messages.isEmpty)
    }

    @Test func ignoresAnEmptyUserMessage() throws {
        let chat = newChat()
        chat.handle(try event(#"{"type":"message_start","message":{"role":"user","content":[]}}"#))
        #expect(chat.messages.isEmpty)
    }

    @Test func handsBackBothQueuesForRecovery() throws {
        let data = try event(#"{"steering":["a","b"],"followUp":["c"]}"#)
        #expect(Chat.queued(data) == ["a", "b", "c"])
    }

    @Test func handsBackNothingWhenTheQueueWasEmpty() throws {
        #expect(Chat.queued(try event(#"{"steering":[],"followUp":[]}"#)).isEmpty)
        #expect(Chat.queued(nil).isEmpty)
    }

    @Test func recoveredTextIsTakenOnlyOnce() {
        let chat = newChat()
        chat.setRecoveredForTesting(["put me back"])

        #expect(chat.takeRecovered() == ["put me back"])
        #expect(chat.takeRecovered().isEmpty)
    }
}
