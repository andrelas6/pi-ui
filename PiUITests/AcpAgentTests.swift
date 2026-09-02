import Foundation
import Testing

@testable import PiUI

struct AcpPathTests {
    @Test func failsWhenTheVariableIsMissing() {
        #expect(throws: AcpPath.Problem.notSet) {
            try AcpPath.fromEnvironment([:])
        }
    }

    @Test func failsWhenTheVariableIsBlank() {
        #expect(throws: AcpPath.Problem.notSet) {
            try AcpPath.fromEnvironment(["ACP_PATH": "  "])
        }
    }

    @Test func failsWhenThePathDoesNotExist() {
        #expect(throws: AcpPath.Problem.missing("/nope/acp")) {
            try AcpPath.fromEnvironment(["ACP_PATH": "/nope/acp"])
        }
    }

    @Test func failsWhenTheFileIsNotExecutable() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "acp-\(UUID().uuidString)")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(throws: AcpPath.Problem.notExecutable(file.path)) {
            try AcpPath.fromEnvironment(["ACP_PATH": file.path])
        }
    }

    /// It is its own variable: pointing at pi must not accidentally start Claude.
    @Test func doesNotReadPisVariable() {
        #expect(throws: AcpPath.Problem.notSet) {
            try AcpPath.fromEnvironment(["PI_PATH": "/usr/bin/true"])
        }
    }

    @Test func acceptsAnExecutable() throws {
        let found = try AcpPath.fromEnvironment(["ACP_PATH": "/usr/bin/true"])
        #expect(found.path == "/usr/bin/true")
    }
}

/// The permission card's three buttons have to land on the option the adapter actually
/// offered, and it names them by kind rather than by id.
struct PermissionChoiceTests {
    private func options(_ json: String) throws -> [JSONValue] {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)).array ?? []
    }

    private let live = #"""
    [{"optionId":"allow-once","name":"Yes","kind":"allow_once"},
     {"optionId":"allow-with-updates","name":"Yes, allow all edits","kind":"allow_always"},
     {"optionId":"reject","name":"No","kind":"reject_once"}]
    """#

    @Test func picksEachOptionByKind() throws {
        let offered = try options(live)
        #expect(ClaudeAgent.option(for: .allow, among: offered) == "allow-once")
        #expect(ClaudeAgent.option(for: .always, among: offered) == "allow-with-updates")
        #expect(ClaudeAgent.option(for: .deny, among: offered) == "reject")
    }

    /// Not every tool offers a standing yes; "always" then has to still allow this one.
    @Test func fallsBackToAllowOnceWhenThereIsNoStandingYes() throws {
        let offered = try options(#"""
        [{"optionId":"a","kind":"allow_once"},{"optionId":"r","kind":"reject_once"}]
        """#)
        #expect(ClaudeAgent.option(for: .always, among: offered) == "a")
    }

    @Test func fallsBackToRejectAlwaysWhenThatIsTheOnlyNo() throws {
        let offered = try options(#"""
        [{"optionId":"a","kind":"allow_once"},{"optionId":"r","kind":"reject_always"}]
        """#)
        #expect(ClaudeAgent.option(for: .deny, among: offered) == "r")
    }

    @Test func takesWhateverIsThereWhenNoKindMatches() throws {
        let offered = try options(#"[{"optionId":"only","kind":"something_new"}]"#)
        #expect(ClaudeAgent.option(for: .allow, among: offered) == "only")
    }

    @Test func hasNothingToPickFromAnEmptyList() {
        #expect(ClaudeAgent.option(for: .allow, among: []) == nil)
    }
}

@MainActor
struct SavedSessionAgentTests {
    private func store(_ json: String) throws -> SessionStore {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-index-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: file)
        return SessionStore(file: file)
    }

    /// Every session in an index written before this change was a pi session, and the
    /// field is simply absent there.
    @Test func readsAnIndexWrittenBeforeClaudeExisted() throws {
        let old = try store(#"""
        [{"id":"one","folder":"file:///tmp/a","everSaved":true,
          "createdAt":757000000,"lastOpenedAt":757000000}]
        """#)

        #expect(old.sessions.count == 1)
        #expect(old.sessions[0].runs == .pi)
    }

    @Test func remembersWhichAgentASessionRunsOn() throws {
        let index = try store("[]")
        index.remember(id: "c", folder: URL(fileURLWithPath: "/tmp/a"), file: nil, agent: .claude)
        index.remember(id: "p", folder: URL(fileURLWithPath: "/tmp/a"), file: nil, agent: .pi)

        #expect(index.session("c")?.runs == .claude)
        #expect(index.session("p")?.runs == .pi)
    }

    /// Reopening has to reach for the same agent after a relaunch, so it must survive
    /// the round trip to disk.
    @Test func keepsTheAgentAcrossALaunch() throws {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-index-\(UUID().uuidString).json")
        let first = SessionStore(file: file)
        first.remember(id: "c", folder: URL(fileURLWithPath: "/tmp/a"), file: nil, agent: .claude)

        #expect(SessionStore(file: file).session("c")?.runs == .claude)
    }

    @Test func defaultsToPiWhenNobodySaid() throws {
        let index = try store("[]")
        index.remember(id: "x", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        #expect(index.session("x")?.runs == .pi)
    }
}

struct AgentNamingTests {
    @Test func namesBothAgents() {
        #expect(Agent.pi.name == "pi")
        #expect(Agent.claude.name == "Claude")
        #expect(Agent.claude.newSessionTitle == "New Claude session…")
    }

    /// The index stores the raw value, so renaming a case would strand saved sessions.
    @Test func storesAStableRawValue() {
        #expect(Agent.pi.rawValue == "pi")
        #expect(Agent.claude.rawValue == "claude")
        #expect(Agent(rawValue: "claude") == .claude)
    }
}
