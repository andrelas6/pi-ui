import Foundation
import Testing

@testable import PiUI

/// The subprocess both agents share. pi and the ACP adapter differ in what their JSON means,
/// not in how it is framed.
struct AgentProcessTests {
    private func process(
        _ command: String,
        _ arguments: [String],
        log: EventLog = .shared
    ) -> AgentProcess {
        AgentProcess(
            executable: URL(fileURLWithPath: command),
            arguments: arguments,
            folder: FileManager.default.temporaryDirectory,
            channel: "test",
            log: log
        )
    }

    private func logFolder() -> URL {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-log-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    private func logged(in folder: URL) throws -> [JSONValue] {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
        return try files.flatMap { file in
            try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
        }
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

    /// A line we cannot read is a protocol mismatch, which is exactly the thing worth
    /// knowing about; dropping it silently hides it completely.
    @Test func writesDownALineItCannotRead() async throws {
        let folder = logFolder()
        let log = EventLog(folder: folder)
        let agent = process("/bin/echo", ["this is not json"], log: log)
        try await agent.start()

        for await _ in agent.lines {}
        try? await Task.sleep(for: .milliseconds(200))

        let found = try logged(in: folder)
        let undecodable = try #require(found.first { $0["event"]?.string == "undecodable" })
        #expect(undecodable["line"]?.string == "this is not json")
    }

    /// The traffic itself is the point of the log.
    @Test func writesDownBothDirections() async throws {
        let folder = logFolder()
        let log = EventLog(folder: folder)
        let agent = process("/bin/cat", [], log: log)
        try await agent.start()
        try await agent.write(.object(["type": .string("ping")]))

        for await value in agent.lines {
            #expect(value["type"]?.string == "ping")
            break
        }
        await agent.stop()
        try? await Task.sleep(for: .milliseconds(200))

        let wire = try logged(in: folder).filter { $0["kind"]?.string == "wire" }
        #expect(wire.contains { $0["dir"]?.string == "out" })
        #expect(wire.contains { $0["dir"]?.string == "in" })
    }

    /// The child environment is built from the user's own, which carries API keys.
    @Test func neverWritesDownTheEnvironment() async throws {
        let folder = logFolder()
        let log = EventLog(folder: folder)
        let agent = process("/bin/echo", ["{}"], log: log)
        try await agent.start()
        for await _ in agent.lines {}
        try? await Task.sleep(for: .milliseconds(200))

        let spawn = try #require(try logged(in: folder).first { $0["event"]?.string == "spawn" })
        #expect(spawn["executable"]?.string == "/bin/echo")
        #expect(spawn["environment"] == nil)
        #expect(spawn["PATH"] == nil)
    }

    /// Agents write ordinary progress to stderr. Treating any of it as a reason reported a
    /// healthy session as a failed one, which the event log is how we noticed.
    @Test func doesNotCallChattyStderrAFailure() async throws {
        let agent = process("/bin/sh", ["-c", "echo 'just so you know' >&2; sleep 0.3"])
        try await agent.start()
        try? await Task.sleep(for: .milliseconds(120))

        #expect(await agent.stderrText == "just so you know")
        #expect(await agent.exitStatus == nil, "still running, so nothing has failed")
    }
}
