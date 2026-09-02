import Foundation

/// pi behind the shared protocol. Every call here is the one `Chat` used to make on
/// `PiSession` directly, so pi's behaviour is unchanged by construction.
final class PiAgent: AgentSession {
    private let session: PiSession
    private let extraArguments: [String]

    init(executable: URL, folder: URL, arguments: [String] = []) {
        session = PiSession(executable: executable, folder: folder)
        extraArguments = arguments
    }

    var events: AsyncStream<JSONValue> {
        session.events
    }

    func open(sessionId: String?) async throws -> OpenedSession {
        let arguments = extraArguments + (sessionId.map { ["--session-id", $0] } ?? [])
        try await session.start(arguments: arguments)

        let state = try await session.send("get_state")
        guard let id = state["data"]?["sessionId"]?.string else {
            throw PiSession.Failure.couldNotStart("pi did not report a session id.")
        }

        var opened = OpenedSession(id: id)
        opened.file = state["data"]?["sessionFile"]?.string.map { URL(fileURLWithPath: $0) }
        opened.modelName = state["data"]?["model"]?["name"]?.string ?? ""
        opened.thinkingLevel = state["data"]?["thinkingLevel"]?.string ?? ""

        let stored = try await session.send("get_messages")
        if let messages = stored["data"]?["messages"]?.array, !messages.isEmpty {
            opened.messages = History.messages(from: messages)
        }
        return opened
    }

    func stop() async {
        await session.stop()
    }

    func prompt(_ text: String) async throws {
        try await session.send("prompt", fields: ["message": .string(text)])
    }

    func steer(_ text: String, followUp: Bool) async throws {
        try await session.send(followUp ? "follow_up" : "steer", fields: ["message": .string(text)])
    }

    func abort() async throws {
        try await session.send("abort")
    }

    func clearQueue() async throws -> [String] {
        let cleared = try await session.send("clear_queue")
        return Chat.queued(cleared["data"])
    }

    func answer(id: String, choice: PermissionChoice) async throws {
        try await session.post([
            "type": .string("extension_ui_response"),
            "id": .string(id),
            "confirmed": .bool(choice != .deny),
        ])
    }

    func answer(id: String, value: String) async throws {
        try await session.post([
            "type": .string("extension_ui_response"),
            "id": .string(id),
            "value": .string(value),
        ])
    }

    func dismiss(id: String) async throws {
        try await session.post([
            "type": .string("extension_ui_response"),
            "id": .string(id),
            "cancelled": .bool(true),
        ])
    }

    func rename(to name: String) async throws {
        try await session.send("set_session_name", fields: ["name": .string(name)])
    }

    /// Model pickers, thinking levels, commands and stats are pi-only, and `Chat` asks
    /// for them through here.
    var pi: PiSession { session }
}
