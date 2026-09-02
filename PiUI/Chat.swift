import Foundation
import Observation

@MainActor
@Observable
final class Chat {
    private(set) var folder: URL?
    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false
    private(set) var problem: String?
    private(set) var notice: String?
    private(set) var ask: Ask?
    private(set) var steering: [String] = []
    private(set) var followUps: [String] = []
    private(set) var recovered: [String] = []
    private(set) var typingRequests = 0
    private(set) var alwaysAllowed: Set<String> = []
    private(set) var models: [ModelChoice] = []
    private(set) var modelName = ""
    private(set) var thinkingLevels: [String] = []
    private(set) var thinkingLevel = ""
    private(set) var stats: SessionStats?
    private(set) var files = WorkingCopy()
    private(set) var commands: [PiCommand] = []

    /// The composer's text lives with the session, so switching away and back does not
    /// lose what you had typed.
    var draft = ""
    var onSettled: (@MainActor () -> Void)?
    var queueAsFollowUp = false
    private(set) var openSessionId: String?

    private let store: SessionStore
    private var session: (any AgentSession)?
    /// Which agent this session runs on. The composer reads it: ACP has no steering, so the
    /// controls that promise it belong to pi alone.
    private(set) var agent: Agent = .pi
    /// Model pickers, thinking levels, commands and stats are pi-only for now, and those
    /// methods reach for this directly. Nil for a Claude session, so they no-op.
    private var pi: PiSession?
    private var eventTask: Task<Void, Never>?
    private var streamingId: String?

    init(store: SessionStore) {
        self.store = store
    }

    var isOpen: Bool { session != nil }

    /// Reading a working copy shells out to git three times, so it happens when a
    /// session opens and when a turn lands, not on every keystroke.
    func refreshFiles() {
        guard let folder else { return }
        files = WorkingCopy.read(folder)
    }

    var branch: String? {
        guard let folder else { return nil }
        return store.branches[folder.path]
    }

    func markOpenForTesting(_ id: String) {
        openSessionId = id
    }

    /// Skills, templates and extension commands are discovered by pi at startup, so
    /// this only has to ask once per session.
    func loadCommands() async {
        guard commands.isEmpty, let pi else { return }
        guard let response = try? await pi.send("get_commands") else { return }
        commands = PiCommand.all(from: response)
    }

    func askToType() {
        typingRequests += 1
    }

    /// Write the name to the index for display, and to pi so `pi -r` agrees.
    func rename(_ id: String, to name: String) {
        store.rename(id, to: name)
        guard id == openSessionId, let session else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { try? await session.rename(to: trimmed) }
    }

    func closeIfOpen(_ id: String) {
        guard id == openSessionId else { return }
        close()
        messages = []
    }

    func open(
        _ folder: URL,
        using kind: Agent = .pi,
        sessionId: String? = nil,
        thenType: Bool = false
    ) {
        close()

        let started: any AgentSession
        do {
            started = try Self.make(kind, folder: folder)
        } catch {
            problem = error.localizedDescription
            return
        }

        agent = kind
        pi = (started as? PiAgent)?.pi
        self.folder = folder
        problem = nil
        notice = nil
        ask = nil
        steering = []
        followUps = []
        alwaysAllowed = []
        messages = []

        Task {
            do {
                let opened = try await started.open(sessionId: sessionId)
                self.session = started
                // Settle what the session reported before listening, so replayed history
                // is built against the right model name rather than a blank one.
                await self.adopt(opened, folder: folder, kind: kind)
                self.listen(to: started)
                // The composer only exists once the session is open, so ask from here.
                if thenType { self.askToType() }
            } catch {
                self.problem = error.localizedDescription
                self.pi = nil
            }
        }
    }

    private static func make(_ kind: Agent, folder: URL) throws -> any AgentSession {
        switch kind {
        case .pi:
            PiAgent(
                executable: try PiPath.fromEnvironment(),
                folder: folder,
                arguments: gateArguments
            )
        case .claude:
            ClaudeAgent(executable: try AcpPath.fromEnvironment(), folder: folder)
        }
    }

    /// A Claude session replays its history as ordinary events, so `messages` may already
    /// be filling in by the time this runs; only take what the session handed back.
    private func adopt(_ opened: OpenedSession, folder: URL, kind: Agent) async {
        openSessionId = opened.id
        store.remember(id: opened.id, folder: folder, file: opened.file, agent: kind)
        store.markRunning(opened.id)
        store.refreshBranches()
        refreshFiles()
        modelName = opened.modelName
        thinkingLevel = opened.thinkingLevel
        if !opened.messages.isEmpty {
            messages = opened.messages
        }
        await refreshThinkingLevels()
        await refreshStats()
    }

    func send(_ text: String) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let session else { return }

        notice = nil

        if isStreaming {
            let followUp = queueAsFollowUp
            Task {
                do {
                    try await session.steer(message, followUp: followUp)
                } catch {
                    problem = error.localizedDescription
                }
            }
            return
        }

        isStreaming = true
        Task {
            do {
                try await session.prompt(message)
            } catch {
                problem = error.localizedDescription
                isStreaming = false
            }
        }
    }

    /// Abort alone lets queued messages carry on, so clear the queue first.
    func stopEverything() {
        guard let session else { return }
        Task {
            recovered = (try? await session.clearQueue()) ?? []
            try? await session.abort()
        }
    }

    func clearQueue() {
        guard let session else { return }
        Task {
            recovered = (try? await session.clearQueue()) ?? []
        }
    }

    func setRecoveredForTesting(_ texts: [String]) {
        recovered = texts
    }

    func takeRecovered() -> [String] {
        let text = recovered
        recovered = []
        return text
    }

    nonisolated static func queued(_ data: JSONValue?) -> [String] {
        let steering = data?["steering"]?.array?.compactMap(\.string) ?? []
        let followUp = data?["followUp"]?.array?.compactMap(\.string) ?? []
        return steering + followUp
    }

    func stop() {
        guard let session else { return }
        Task { try? await session.abort() }
    }

    func close() {
        eventTask?.cancel()
        eventTask = nil
        if let session {
            Task { await session.stop() }
        }
        if let openSessionId {
            store.markStopped(openSessionId)
        }
        session = nil
        pi = nil
        folder = nil
        openSessionId = nil
        ask = nil
        isStreaming = false
    }

    private func listen(to agent: any AgentSession) {
        eventTask = Task { [weak self] in
            for await event in agent.events {
                self?.handle(event)
            }
        }
    }

    func handle(_ event: JSONValue) {
        switch event["type"]?.string {
        case "message_update":
            guard let update = event["assistantMessageEvent"] else { return }
            switch update["type"]?.string {
            case "text_start":
                let message = ChatMessage(
                    kind: .assistant,
                    text: "",
                    done: false,
                    kicker: Kickers.agent(model: modelName)
                )
                streamingId = message.id
                messages.append(message)
            case "text_delta":
                guard let delta = update["delta"]?.string else { return }
                append(delta)
            case "text_end":
                finishStreaming()
            default:
                return
            }

        case "tool_execution_start":
            guard let id = event["toolCallId"]?.string,
                  let name = event["toolName"]?.string
            else { return }
            finishStreaming()
            let call = ChatMessage.ToolCall(
                name: name,
                preview: ChatMessage.ToolCall.preview(of: event["args"]),
                arguments: event["args"]?.prettyText ?? "",
                output: "",
                diff: "",
                result: "",
                failed: false
            )
            messages.append(ChatMessage(id: id, kind: .tool, text: "", done: false, tool: call))

        // Tools run concurrently, so match on toolCallId rather than position.
        case "tool_execution_update":
            guard let index = toolIndex(event) else { return }
            messages[index].tool?.output = event["partialResult"]?.contentText ?? ""
            fillIn(event["args"], at: index)
            fillIn(diff: event["diff"]?.string, at: index)

        case "tool_execution_end":
            guard let index = toolIndex(event) else { return }
            fillIn(event["args"], at: index)
            messages[index].tool?.output = event["result"]?.contentText ?? ""
            // pi computes the diff itself, so there is no need to reinvent one.
            fillIn(diff: event["result"]?["details"]?["diff"]?.string, at: index)
            messages[index].tool?.failed = event["isError"]?.bool ?? false
            messages[index].done = true

        case "message_end":
            guard let message = event["message"],
                  message["role"]?.string == "assistant",
                  message["stopReason"]?.string == "error"
            else { return }
            problem = Self.readable(message["errorMessage"]?.string)
            finishStreaming()
            isStreaming = false

        case "message_start":
            guard let message = event["message"], message["role"]?.string == "user" else { return }
            let text = History.plainText(message["content"])
            guard !text.isEmpty else { return }
            let at = Kickers.moment(fromMilliseconds: message["timestamp"]?.number)
            messages.append(
                ChatMessage(kind: .user, text: text, done: true, kicker: Kickers.user(at: at))
            )

        case "queue_update":
            steering = event["steering"]?.array?.compactMap(\.string) ?? []
            followUps = event["followUp"]?.array?.compactMap(\.string) ?? []

        case "extension_ui_request":
            receive(event)

        case "agent_settled":
            closeUnansweredRequests()
            finishStreaming()
            isStreaming = false
            steering = []
            followUps = []
            store.reconcile()
            store.refreshBranches()
            refreshFiles()
            onSettled?()
            Task { await refreshStats() }

        default:
            break
        }
    }

    private func receive(_ event: JSONValue) {
        switch event["method"]?.string {
        case "notify":
            notice = event["message"]?.string
        // Anything else is fire-and-forget and has no home in this UI yet.
        default:
            guard let waiting = Ask(event) else { return }
            if waiting.method == .confirm, alwaysAllowed.contains(waiting.title) {
                answer(waiting, confirmed: true)
                return
            }
            ask = waiting
            guard waiting.method == .confirm else { return }
            messages.append(
                ChatMessage(
                    id: waiting.id,
                    kind: .permission,
                    text: "",
                    done: false,
                    kicker: "permission requested",
                    request: ChatMessage.Request(
                        tool: waiting.title,
                        detail: waiting.message,
                        answer: ""
                    )
                )
            )
        }
    }

    /// Remembered for this session only. A standing yes that outlived the window
    /// would be a permission you never granted.
    func alwaysAllow(_ ask: Ask) {
        alwaysAllowed.insert(ask.title)
        respond { try await $0.answer(id: ask.id, choice: .always) }
    }

    func forgetAllowances() {
        alwaysAllowed = []
    }

    func answer(_ ask: Ask, confirmed: Bool) {
        respond { try await $0.answer(id: ask.id, choice: confirmed ? .allow : .deny) }
    }

    func answer(_ ask: Ask, value: String) {
        respond { try await $0.answer(id: ask.id, value: value) }
    }

    func dismiss(_ ask: Ask) {
        respond { try await $0.dismiss(id: ask.id) }
    }

    /// Answering from the log: the card records what was chosen and stops offering.
    func answerRequest(id: String, choice: String) {
        guard let waiting = ask, waiting.id == id else { return }
        if let index = messages.firstIndex(where: { $0.id == id && $0.kind == .permission }) {
            messages[index].request?.answer = choice
            messages[index].done = true
        }

        switch choice {
        case ChatMessage.Request.always: alwaysAllow(waiting)
        case ChatMessage.Request.allow: answer(waiting, confirmed: true)
        default: answer(waiting, confirmed: false)
        }
    }

    /// The agent blocks until a permission request is answered, so a reply that never
    /// lands hangs the turn with nothing on screen. Say it out loud instead.
    private func respond(
        _ work: @escaping @Sendable (any AgentSession) async throws -> Void
    ) {
        ask = nil
        guard let running = session else {
            problem = "There is no session open to answer that."
            return
        }
        Task {
            do {
                try await work(running)
            } catch {
                problem = "Could not answer the request: \(error.localizedDescription)"
            }
        }
    }

    /// pi ships no permission prompts, so the app brings its own gate.
    private static var gateArguments: [String] {
        guard let gate = Bundle.main.url(forResource: "permission-gate", withExtension: "js") else {
            return []
        }
        return ["-e", gate.path]
    }

    func loadModels() async {
        guard models.isEmpty, let pi else { return }
        guard let response = try? await pi.send("get_available_models") else { return }
        models = ModelChoice.all(from: response)
    }

    func use(_ choice: ModelChoice) async {
        guard let pi else { return }
        guard let response = try? await pi.send(
            "set_model",
            fields: ["provider": .string(choice.provider), "modelId": .string(choice.modelId)]
        ) else { return }

        modelName = response["data"]?["name"]?.string ?? choice.name
        // Levels belong to the model, so a switch can leave the old one unavailable.
        await refreshThinkingLevels()
        await refreshStats()
    }

    /// pi answers success for a level the model does not offer and then ignores it,
    /// so only ever send one from this list.
    func setThinking(_ level: String) async {
        guard let pi, thinkingLevels.contains(level) else { return }
        guard (try? await pi.send("set_thinking_level", fields: ["level": .string(level)])) != nil
        else { return }
        thinkingLevel = level
    }

    private func refreshThinkingLevels() async {
        guard let pi else { return }
        guard let response = try? await pi.send("get_available_thinking_levels") else { return }
        thinkingLevels = response["data"]?["levels"]?.array?.compactMap(\.string) ?? []

        if !thinkingLevels.contains(thinkingLevel) {
            thinkingLevel = thinkingLevels.first ?? ""
        }
    }

    private func refreshStats() async {
        guard let pi else { return }
        guard let response = try? await pi.send("get_session_stats") else { return }
        stats = SessionStats(response)
    }

    /// Some agents announce a tool call before they know what they are calling it with,
    /// and fill the arguments in as they go. pi sends them up front, so this never fires
    /// for a pi session.
    private func fillIn(_ args: JSONValue?, at index: Int) {
        guard let args else { return }
        messages[index].tool?.arguments = args.prettyText
        messages[index].tool?.preview = ChatMessage.ToolCall.preview(of: args)
    }

    /// Some agents stream the diff on the updates before a call ends and send none with
    /// the end itself, so an empty one must not wipe what those updates established.
    private func fillIn(diff: String?, at index: Int) {
        guard let diff, !diff.isEmpty else { return }
        messages[index].tool?.diff = diff
        messages[index].tool?.result = DiffSummary.text(diff)
    }

    private func toolIndex(_ event: JSONValue) -> Int? {
        guard let id = event["toolCallId"]?.string else { return nil }
        return messages.firstIndex { $0.id == id && $0.kind == .tool }
    }

    private func append(_ delta: String) {
        guard let streamingId,
              let index = messages.firstIndex(where: { $0.id == streamingId })
        else { return }
        messages[index].text += delta
    }

    private func closeUnansweredRequests() {
        for index in messages.indices where messages[index].kind == .permission {
            guard messages[index].done == false else { continue }
            messages[index].done = true
        }
    }

    private func finishStreaming() {
        guard let streamingId,
              let index = messages.firstIndex(where: { $0.id == streamingId })
        else { return }
        messages[index].done = true
        self.streamingId = nil
    }

    /// Provider errors arrive as `402: {"message":"…"}`. Show the sentence, not the blob.
    static func readable(_ error: String?) -> String {
        guard let error, !error.isEmpty else { return "The model returned an error." }
        guard let start = error.range(of: "\"message\":\"") else { return error }
        let rest = error[start.upperBound...]
        guard let end = rest.range(of: "\"") else { return error }
        let prefix = error[error.startIndex..<start.lowerBound]
            .trimmingCharacters(in: CharacterSet(charactersIn: " :{"))
        let sentence = rest[rest.startIndex..<end.lowerBound]
        return prefix.isEmpty ? String(sentence) : "\(prefix): \(sentence)"
    }
}
