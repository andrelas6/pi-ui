import Foundation
import Testing

@testable import PiUI

/// The subprocess both agents share. pi and the ACP adapter differ in what their JSON means,
/// not in how it is framed.
struct AgentProcessTests {
    private func process(_ command: String, _ arguments: [String]) -> AgentProcess {
        AgentProcess(
            executable: URL(fileURLWithPath: command),
            arguments: arguments,
            folder: FileManager.default.temporaryDirectory
        )
    }

    @Test func readsOneValuePerLine() async throws {
        let agent = process("/bin/echo", [#"{"type":"a"}"# + "\n" + #"{"type":"b"}"#])
        try await agent.start()

        var seen: [String] = []
        for await value in agent.lines {
            seen.append(value["type"]?.string ?? "?")
        }
        #expect(seen == ["a", "b"])
    }

    /// A line split across reads must not decode as two broken halves.
    @Test func joinsAValueSplitAcrossChunks() async throws {
        let big = String(repeating: "x", count: 100_000)
        let agent = process("/bin/echo", [#"{"type":"big","text":"\#(big)"}"#])
        try await agent.start()

        var found: JSONValue?
        for await value in agent.lines { found = value }
        #expect(found?["text"]?.string?.count == 100_000)
    }

    /// An agent that dies on launch explains itself on stderr and nowhere else.
    @Test func keepsWhatAFailingAgentSaid() async throws {
        let agent = process("/bin/sh", ["-c", "echo 'no such thing' >&2; exit 3"])
        try await agent.start()

        for await _ in agent.lines {}
        // The exit status arrives on its own handler, so give it the turn it needs.
        try? await Task.sleep(for: .milliseconds(200))

        #expect(await agent.stderrText == "no such thing")
        #expect(await agent.exitStatus == 3)
    }

    @Test func refusesToWriteBeforeItStarts() async throws {
        let agent = process("/bin/cat", [])
        await #expect(throws: AgentProcess.Failure.self) {
            try await agent.write(.object(["type": .string("x")]))
        }
    }

    @Test func failsLoudlyWhenTheExecutableIsNotThere() async throws {
        let agent = process("/nope/not-an-agent", [])
        await #expect(throws: AgentProcess.Failure.self) {
            try await agent.start()
        }
    }
}
