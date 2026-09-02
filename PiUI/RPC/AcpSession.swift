import Foundation

/// JSON-RPC 2.0 over an `AgentProcess`. The one thing pi's protocol never needed: the agent
/// can call *us*, and those calls have to be answered.
actor AcpSession {
    enum Failure: Error, LocalizedError {
        case notRunning
        case couldNotStart(String)
        case refused(String)

        var errorDescription: String? {
            switch self {
            case .notRunning:
                "The ACP adapter is not running."
            case .couldNotStart(let reason):
                "Could not start the ACP adapter: \(reason)"
            case .refused(let message):
                message
            }
        }
    }

    private let executable: URL
    private let folder: URL

    private var child: AgentProcess?
    private var waiting: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var counter = 0
    private var readTask: Task<Void, Never>?

    /// Everything the agent sends us: `session/update` notifications, and requests such as
    /// `session/request_permission` that expect a reply.
    let incoming: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    init(executable: URL, folder: URL) {
        self.executable = executable
        self.folder = folder
        (incoming, publish) = AsyncStream.makeStream()
    }

    func start() async throws {
        guard child == nil else { return }

        let child = AgentProcess(executable: executable, arguments: [], folder: folder)

        do {
            try await child.start()
        } catch let failure as AgentProcess.Failure {
            throw Self.failure(from: failure, said: await child.stderrText)
        }

        self.child = child
        readTask = Task { [weak self] in
            for await value in child.lines {
                await self?.route(value)
            }
            await self?.finish()
        }
    }

    @discardableResult
    func request(_ method: String, _ params: JSONValue = .object([:])) async throws -> JSONValue {
        guard let child else { throw try await failure() }

        counter += 1
        let id = counter

        return try await withCheckedThrowingContinuation { continuation in
            waiting[id] = continuation
            Task {
                do {
                    try await child.write(.object([
                        "jsonrpc": .string("2.0"),
                        "id": .number(Double(id)),
                        "method": .string(method),
                        "params": params,
                    ]))
                } catch {
                    resume(id, throwing: error)
                }
            }
        }
    }

    func notify(_ method: String, _ params: JSONValue = .object([:])) async throws {
        guard let child else { throw try await failure() }
        try await child.write(.object([
            "jsonrpc": .string("2.0"),
            "method": .string(method),
            "params": params,
        ]))
    }

    /// Answering a request the agent made of us. The id comes back exactly as it arrived —
    /// JSON-RPC lets it be a number or a string.
    func respond(to id: JSONValue, result: JSONValue) async throws {
        guard let child else { throw try await failure() }
        try await child.write(.object([
            "jsonrpc": .string("2.0"),
            "id": id,
            "result": result,
        ]))
    }

    func stop() async {
        readTask?.cancel()
        readTask = nil
        await child?.stop()
        await finish()
    }

    private func resume(_ id: Int, throwing error: Error) {
        waiting.removeValue(forKey: id)?.resume(throwing: error)
    }

    /// A message with a method is the agent talking to us, whether or not it wants a reply.
    /// Anything else carrying an id is an answer to something we asked.
    private func route(_ value: JSONValue) {
        if value["method"] != nil {
            publish.yield(value)
            return
        }

        guard let id = value["id"]?.number.map({ Int($0) }),
              let waiter = waiting.removeValue(forKey: id)
        else { return }

        if let refusal = value["error"] {
            let message = refusal["message"]?.string ?? "The agent refused the request."
            waiter.resume(throwing: Failure.refused(message))
        } else {
            waiter.resume(returning: value["result"] ?? .object([:]))
        }
    }

    private func finish() async {
        let reason = (try? await failure()) ?? Failure.notRunning
        for waiter in waiting.values {
            waiter.resume(throwing: reason)
        }
        waiting.removeAll()
        publish.finish()
        child = nil
    }

    /// An adapter that dies on launch — a missing node, a bad path — says why on stderr.
    /// Repeating "not running" would throw that away, which is the whole diagnosis.
    private func failure() async throws -> Failure {
        guard let child else { return .notRunning }
        let said = await child.stderrText
        if !said.isEmpty {
            return .couldNotStart(said)
        }
        if let status = await child.exitStatus {
            return .couldNotStart("The adapter exited with status \(status).")
        }
        return .notRunning
    }

    private static func failure(from failure: AgentProcess.Failure, said: String) -> Failure {
        switch failure {
        case .notRunning:
            .notRunning
        case .couldNotStart(let reason):
            .couldNotStart(said.isEmpty ? reason : said)
        }
    }
}
