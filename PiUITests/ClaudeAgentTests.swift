import Foundation
import Testing

@testable import PiUI

func acpIsConfigured() -> Bool {
    (try? AcpPath.fromEnvironment()) != nil
}

struct WaitedTooLong: Error, CustomStringConvertible {
    let what: String
    var description: String { "timed out waiting for \(what)" }
}

/// Live turns take as long as the model takes, so tests wait on what they need rather than
/// on a fixed sleep. The `.timeLimit` trait is the backstop if this never comes true.
@MainActor
func waitFor(_ what: String, _ done: () -> Bool) async throws {
    for _ in 0..<900 {
        if done() { return }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw WaitedTooLong(what: what)
}

/// Drives the real adapter, the way `PiSessionTests` drives real pi. Skipped unless
/// `TEST_RUNNER_ACP_PATH` points at one.
@Suite(.serialized)
struct ClaudeAgentTests {
    private func folder() -> URL {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-acp-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    @Test(.enabled(if: acpIsConfigured()), .timeLimit(.minutes(1)))
    func opensASessionAndAnswersAPrompt() async throws {
        let agent = ClaudeAgent(executable: try AcpPath.fromEnvironment(), folder: folder())
        let opened = try await agent.open(sessionId: nil)
        #expect(opened.id.isEmpty == false)

        let collected = Task {
            var seen: [JSONValue] = []
            for await event in agent.events {
                seen.append(event)
                if event["type"]?.string == "agent_settled" { break }
            }
            return seen
        }

        try await agent.prompt("Reply with exactly: OK")
        let events = await collected.value
        await agent.stop()

        let kinds = events.compactMap { $0["type"]?.string }
        #expect(kinds.first == "message_start")
        #expect(kinds.contains("message_update"))
        #expect(kinds.last == "agent_settled")

        let text = events
            .compactMap { $0["assistantMessageEvent"]?["delta"]?.string }
            .joined()
        #expect(text.contains("OK"))
    }

}

/// These drive `Chat.open` rather than wiring a session by hand, so the permission reply
/// goes back through the same path the app uses — answering a card is routed by `Chat` to
/// whichever agent it opened.
@MainActor
@Suite(.serialized)
struct ClaudeToolCardTests {
    private func session() throws -> (Chat, URL) {
        let work = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-acp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-index-\(UUID().uuidString).json")
        let chat = Chat(store: SessionStore(file: index))
        chat.open(work, using: .claude)
        return (chat, work)
    }

    /// Polls on the main actor, answering any permission the agent raises, until the turn
    /// produces what the test is waiting for.
    private func run(_ chat: Chat, _ prompt: String, until done: () -> Bool) async throws {
        try await waitFor("the session to open") { chat.isOpen }
        chat.send(prompt)
        try await waitFor("the turn to produce a tool card") {
            if let ask = chat.ask {
                chat.answerRequest(id: ask.id, choice: ChatMessage.Request.allow)
            }
            return done()
        }
        chat.close()
    }

    @Test(.enabled(if: acpIsConfigured()), .timeLimit(.minutes(1)))
    func showsTheCommandOnABashCard() async throws {
        let (chat, _) = try session()
        try await run(chat, "Run the shell command: echo hello-from-bash") {
            chat.messages.contains { $0.tool?.preview.contains("echo") == true }
        }

        let tool = try #require(chat.messages.compactMap(\.tool).first { $0.preview.contains("echo") })
        #expect(tool.arguments != "{}")
        #expect(tool.arguments.contains("echo"))
    }

    /// The diff lands on an update partway through the call, not on the one that says it
    /// finished — building it only at the end left every edit without a diff.
    @Test(.enabled(if: acpIsConfigured()), .timeLimit(.minutes(1)))
    func showsADiffForARealEdit() async throws {
        let (chat, work) = try session()
        try "alpha\nbravo\ncharlie\n".write(
            to: work.appending(path: "edit-me.txt"), atomically: true, encoding: .utf8
        )

        try await run(chat, "In edit-me.txt change bravo to BRAVO. Use the Edit tool.") {
            chat.messages.contains { $0.tool?.diff.isEmpty == false }
        }

        let edit = try #require(
            chat.messages.compactMap(\.tool).first { !$0.diff.isEmpty },
            "no tool call came back with a diff"
        )
        #expect(edit.diff.contains("-bravo"))
        #expect(edit.diff.contains("+BRAVO"))
        #expect(edit.result == "+1 −1")
    }
}

@MainActor
@Suite(.serialized)
struct ClaudeReplayTests {
    /// Reopening a session replays its history and then stops. The last answer used to be
    /// left open, which draws it as raw streaming text — its markdown never parsed.
    @Test(.enabled(if: acpIsConfigured()), .timeLimit(.minutes(1)))
    func marksReplayedAnswersDone() async throws {
        let work = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-acp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let path = try AcpPath.fromEnvironment()

        let first = ClaudeAgent(executable: path, folder: work)
        let opened = try await first.open(sessionId: nil)
        let done = Task { for await e in first.events where e["type"]?.string == "agent_settled" { return } }
        try await first.prompt("Reply with exactly this markdown and nothing else: ## Title")
        await done.value
        await first.stop()

        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-index-\(UUID().uuidString).json")
        let chat = Chat(store: SessionStore(file: index))
        let again = ClaudeAgent(executable: path, folder: work)
        _ = try await again.open(sessionId: opened.id)

        let replayed = Task { @MainActor in
            for await event in again.events { chat.handle(event) }
        }
        try? await Task.sleep(for: .seconds(3))
        replayed.cancel()
        await again.stop()

        let answer = try #require(chat.messages.last(where: { $0.kind == .assistant }))
        #expect(answer.done, "a replayed answer that never closes never gets its markdown parsed")
    }
}
