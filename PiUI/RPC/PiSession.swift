import Foundation

/// pi's own JSONL protocol: flat objects carrying a `type`, and a `response` matched back to
/// the request that asked for it. The subprocess underneath is an `AgentProcess`.
actor PiSession {
    enum Failure: Error, LocalizedError {
        case notRunning
        case couldNotStart(String)

        var errorDescription: String? {
            switch self {
            case .notRunning:
                "The pi process is not running."
            case .couldNotStart(let reason):
                "Could not start pi: \(reason)"
            }
        }
    }

    private let executable: URL
    private let folder: URL

    private var child: AgentProcess?
    private var waiting: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var counter = 0
    private var readTask: Task<Void, Never>?

    let events: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    init(executable: URL, folder: URL) {
        self.executable = executable
        self.folder = folder
        (events, publish) = AsyncStream.makeStream()
    }

    func start(arguments: [String] = []) async throws {
        guard child == nil else { return }

        let child = AgentProcess(
            executable: executable,
            arguments: ["--mode", "rpc"] + arguments,
            folder: folder,
            channel: "pi:\(folder.lastPathComponent)"
        )

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
    func send(_ type: String, fields: [String: JSONValue] = [:]) async throws -> JSONValue {
        guard let child else { throw Failure.notRunning }

        counter += 1
        let id = "r\(counter)"
        var payload = fields
        payload["type"] = .string(type)
        payload["id"] = .string(id)

        return try await withCheckedThrowingContinuation { continuation in
            waiting[id] = continuation
            Task {
                do {
                    try await child.write(.object(payload))
                } catch {
                    resume(id, throwing: error)
                }
            }
        }
    }

    /// Extension UI replies carry the request's own id and get no response back,
    /// so they cannot go through `send`.
    func post(_ fields: [String: JSONValue]) async throws {
        guard let child else { throw Failure.notRunning }
        try await child.write(.object(fields))
    }

    func stop() async {
        readTask?.cancel()
        readTask = nil
        await child?.stop()
        finish()
    }

    private func resume(_ id: String, throwing error: Error) {
        waiting.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func route(_ value: JSONValue) {
        if value["type"]?.string == "response",
           let id = value["id"]?.string,
           let waiter = waiting.removeValue(forKey: id) {
            waiter.resume(returning: value)
        } else {
            publish.yield(value)
        }
    }

    private func finish() {
        for waiter in waiting.values {
            waiter.resume(throwing: Failure.notRunning)
        }
        waiting.removeAll()
        publish.finish()
        child = nil
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
