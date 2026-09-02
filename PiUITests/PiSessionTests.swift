import Foundation
import Testing

@testable import PiUI

func piIsConfigured() -> Bool {
    (try? PiPath.fromEnvironment()) != nil
}

struct PiSessionTests {
    @Test(.enabled(if: piIsConfigured()))
    func getStateReportsModelAndSession() async throws {
        let executable = try PiPath.fromEnvironment()
        let sessions = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "pi-ui-tests-\(UUID().uuidString)")

        let session = PiSession(
            executable: executable,
            folder: FileManager.default.temporaryDirectory
        )
        try await session.start(arguments: ["--session-dir", sessions.path])
        let response = try await session.send("get_state")

        #expect(response["type"]?.string == "response")
        #expect(response["command"]?.string == "get_state")
        #expect(response["success"]?.bool == true)
        #expect(response["id"]?.string == "r1")

        let state = try #require(response["data"])
        #expect(state["model"]?["id"]?.string?.isEmpty == false)
        #expect(state["sessionId"]?.string?.isEmpty == false)
        #expect(state["sessionFile"]?.string?.hasSuffix(".jsonl") == true)

        await session.stop()
    }

    @Test(.enabled(if: piIsConfigured()))
    func matchesEachResponseToItsOwnRequest() async throws {
        let executable = try PiPath.fromEnvironment()
        let session = PiSession(
            executable: executable,
            folder: FileManager.default.temporaryDirectory
        )
        try await session.start(arguments: ["--no-session"])

        async let first = session.send("get_state")
        async let second = session.send("get_available_thinking_levels")
        async let third = session.send("get_commands")

        let responses = try await [first, second, third]
        let commands = responses.compactMap { $0["command"]?.string }

        #expect(Set(commands) == ["get_state", "get_available_thinking_levels", "get_commands"])
        for response in responses {
            #expect(response["success"]?.bool == true)
        }

        await session.stop()
    }
}

struct AgentEnvironmentTests {
    @Test func putsPiBinDirectoryFirstOnThePath() {
        let environment = AgentProcess.environment(
            for: URL(fileURLWithPath: "/opt/tools/bin/pi"),
            base: ["PATH": "/usr/bin:/bin"]
        )
        #expect(environment["PATH"] == "/opt/tools/bin:/usr/bin:/bin")
    }

    @Test func suppliesAPathWhenTheParentHasNone() {
        let environment = AgentProcess.environment(
            for: URL(fileURLWithPath: "/opt/tools/bin/pi"),
            base: [:]
        )
        #expect(environment["PATH"] == "/opt/tools/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    }

    @Test func keepsTheRestOfTheEnvironment() {
        let environment = AgentProcess.environment(
            for: URL(fileURLWithPath: "/opt/tools/bin/pi"),
            base: ["PATH": "/usr/bin", "HOME": "/Users/someone"]
        )
        #expect(environment["HOME"] == "/Users/someone")
    }
}
