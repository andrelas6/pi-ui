import Foundation

/// Claude behind the shared protocol, spoken over ACP. Incoming notifications are
/// translated into the app's own event vocabulary by `AcpEvents`; the permission requests
/// the agent makes of us are answered from here.
actor ClaudeAgent: AgentSession {
    private struct Waiting {
        let rpcId: JSONValue
        let options: [JSONValue]
    }

    nonisolated let events: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    private let session: AcpSession
    private let folder: URL

    private var translator = AcpEvents()
    private var sessionId = ""
    private var waiting: [String: Waiting] = [:]
    private var askCounter = 0
    private var turnsInFlight = 0
    private var pump: Task<Void, Never>?

    init(executable: URL, folder: URL) {
        self.folder = folder
        session = AcpSession(executable: executable, folder: folder)
        (events, publish) = AsyncStream.makeStream()
    }

    func open(sessionId existing: String?) async throws -> OpenedSession {
        try await session.start()

        // The pump has to be running before `session/load`: the agent replays the whole
        // conversation as notifications *before* it answers, and those are the history.
        pump = Task { [weak self] in
            guard let self else { return }
            for await message in await self.session.incoming {
                await self.receive(message)
            }
            await self.finish()
        }

        try await session.request("initialize", .object([
            "protocolVersion": .number(1),
            // No `fs` capability on purpose: the agent then reads and writes files itself,
            // which is what we want.
            "clientCapabilities": .object([:]),
        ]))

        let arguments: [String: JSONValue] = [
            "cwd": .string(folder.path),
            "mcpServers": .array([]),
        ]

        if let existing {
            var load = arguments
            load["sessionId"] = .string(existing)
            try await session.request("session/load", .object(load))
            sessionId = existing
            // The replay is finished, so whatever it left open has to be closed.
            for event in translator.closeMessage() {
                publish.yield(event)
            }
            return OpenedSession(id: existing, modelName: Agent.claude.name)
        }

        let made = try await session.request("session/new", .object(arguments))
        guard let id = made["sessionId"]?.string else {
            throw AcpSession.Failure.couldNotStart("The adapter did not return a session id.")
        }
        sessionId = id
        return OpenedSession(id: id, modelName: Agent.claude.name)
    }

    func stop() async {
        pump?.cancel()
        pump = nil
        await session.stop()
    }

    func prompt(_ text: String) async throws {
        publish.yield(AcpEvents.userMessage(text))
        try await run(text)
    }

    /// ACP has no steering channel. The adapter queues prompts, so a message sent while a
    /// turn is running joins the queue rather than interrupting it.
    func steer(_ text: String, followUp: Bool) async throws {
        try await prompt(text)
    }

    private func run(_ text: String) async throws {
        turnsInFlight += 1
        defer {
            turnsInFlight -= 1
            if turnsInFlight == 0 {
                for event in translator.settle() {
                    publish.yield(event)
                }
            }
        }

        try await session.request("session/prompt", .object([
            "sessionId": .string(sessionId),
            "prompt": .array([.object(["type": .string("text"), "text": .string(text)])]),
        ]))
    }

    func abort() async throws {
        try await session.notify("session/cancel", .object(["sessionId": .string(sessionId)]))
    }

    /// Nothing queues on our side, so there is never anything to hand back.
    func clearQueue() async throws -> [String] { [] }

    func answer(id: String, choice: PermissionChoice) async throws {
        guard let pending = waiting.removeValue(forKey: id) else { return }
        guard let option = Self.option(for: choice, among: pending.options) else {
            try await session.respond(to: pending.rpcId, result: cancelled)
            return
        }
        try await session.respond(to: pending.rpcId, result: .object([
            "outcome": .object([
                "outcome": .string("selected"),
                "optionId": .string(option),
            ]),
        ]))
    }

    /// ACP asks only for permission, never for free text, so there is nothing this can be.
    func answer(id: String, value: String) async throws {
        try await dismiss(id: id)
    }

    func dismiss(id: String) async throws {
        guard let pending = waiting.removeValue(forKey: id) else { return }
        try await session.respond(to: pending.rpcId, result: cancelled)
    }

    /// The adapter names sessions itself; the app's own index carries the name instead.
    func rename(to name: String) async throws {}

    private var cancelled: JSONValue {
        .object(["outcome": .object(["outcome": .string("cancelled")])])
    }

    private func receive(_ message: JSONValue) {
        if message["method"]?.string == "session/request_permission" {
            ask(message)
            return
        }
        for event in translator.translate(message) {
            publish.yield(event)
        }
    }

    private func ask(_ message: JSONValue) {
        guard let rpcId = message["id"] else { return }
        let call = message["params"]?["toolCall"]
        let options = message["params"]?["options"]?.array ?? []

        askCounter += 1
        let id = "acp-\(askCounter)"
        waiting[id] = Waiting(rpcId: rpcId, options: options)

        publish.yield(.object([
            "type": .string("extension_ui_request"),
            "id": .string(id),
            "method": .string("confirm"),
            // The tool's name groups "always allow"; the sentence explains this one call.
            "title": .string(call?["name"]?.string ?? "Claude is asking"),
            "message": .string(call?["title"]?.string ?? ""),
        ]))
    }

    private func finish() {
        for id in waiting.keys {
            waiting.removeValue(forKey: id)
        }
        publish.finish()
    }

    /// Options are matched on their declared kind rather than their id, which is the
    /// adapter's to name.
    static func option(for choice: PermissionChoice, among options: [JSONValue]) -> String? {
        let wanted: [String]
        switch choice {
        case .allow: wanted = ["allow_once", "allow_always"]
        case .always: wanted = ["allow_always", "allow_once"]
        case .deny: wanted = ["reject_once", "reject_always"]
        }

        for kind in wanted {
            if let match = options.first(where: { $0["kind"]?.string == kind }),
               let id = match["optionId"]?.string {
                return id
            }
        }
        return options.first?["optionId"]?.string
    }
}
