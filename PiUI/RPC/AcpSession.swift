import Foundation

/// JSON-RPC 2.0 over the adapter's stdio. Same shape as `PiSession` — a process, a line
/// buffer, id-correlated continuations — with the one thing ACP needs and pi never did:
/// the agent can call *us*, and those calls have to be answered.
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

    private var process: Process?
    private var input: FileHandle?
    private var buffer = LineBuffer()
    private var waiting: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var counter = 0
    private var readTask: Task<Void, Never>?
    private var errorOutput = ""
    private var exitStatus: Int32?

    /// Everything the agent sends us: `session/update` notifications, and requests such as
    /// `session/request_permission` that expect a reply.
    let incoming: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    init(executable: URL, folder: URL) {
        self.executable = executable
        self.folder = folder
        (incoming, publish) = AsyncStream.makeStream()
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    var stderrText: String {
        errorOutput
    }

    func start() throws {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = folder
        process.environment = PiSession.environment(
            for: executable,
            base: ProcessInfo.processInfo.environment
        )

        let toAgent = Pipe()
        let fromAgent = Pipe()
        let errors = Pipe()
        process.standardInput = toAgent
        process.standardOutput = fromAgent
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw Failure.couldNotStart(error.localizedDescription)
        }

        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { await self?.noteExit(status) }
        }

        self.process = process
        self.input = toAgent.fileHandleForWriting

        let output = fromAgent.fileHandleForReading
        readTask = Task { [weak self] in
            for await chunk in Self.chunks(from: output) {
                await self?.handle(chunk)
            }
            await self?.finish()
        }

        let errorHandle = errors.fileHandleForReading
        Task { [weak self] in
            for await chunk in Self.chunks(from: errorHandle) {
                await self?.collectError(chunk)
            }
        }
    }

    @discardableResult
    func request(_ method: String, _ params: JSONValue = .object([:])) async throws -> JSONValue {
        guard input != nil else { throw failure() }

        counter += 1
        let id = counter

        return try await withCheckedThrowingContinuation { continuation in
            waiting[id] = continuation
            do {
                try write([
                    "jsonrpc": .string("2.0"),
                    "id": .number(Double(id)),
                    "method": .string(method),
                    "params": params,
                ])
            } catch {
                waiting.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }

    func notify(_ method: String, _ params: JSONValue = .object([:])) throws {
        try write([
            "jsonrpc": .string("2.0"),
            "method": .string(method),
            "params": params,
        ])
    }

    /// Answering a request the agent made of us. The id comes back exactly as it arrived —
    /// JSON-RPC lets it be a number or a string.
    func respond(to id: JSONValue, result: JSONValue) throws {
        try write([
            "jsonrpc": .string("2.0"),
            "id": id,
            "result": result,
        ])
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        try? input?.close()
        process?.terminate()
        finish()
    }

    private func write(_ fields: [String: JSONValue]) throws {
        guard let input else { throw failure() }
        let line = try JSONEncoder().encode(JSONValue.object(fields))
        try input.write(contentsOf: line)
        try input.write(contentsOf: Data([0x0A]))
    }

    private func handle(_ chunk: Data) {
        for line in buffer.take(chunk) {
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: line) else { continue }
            route(value)
        }
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

        if let failure = value["error"] {
            let message = failure["message"]?.string ?? "The agent refused the request."
            waiter.resume(throwing: Failure.refused(message))
        } else {
            waiter.resume(returning: value["result"] ?? .object([:]))
        }
    }

    private func collectError(_ chunk: Data) {
        errorOutput += String(decoding: chunk, as: UTF8.self)
    }

    private func noteExit(_ status: Int32) {
        exitStatus = status
    }

    /// An adapter that dies on launch — a missing node, a bad path — says why on stderr.
    /// Repeating "not running" would throw that away, which is the whole diagnosis.
    private func failure() -> Failure {
        let said = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !said.isEmpty {
            return .couldNotStart(said)
        }
        if let exitStatus {
            return .couldNotStart("The adapter exited with status \(exitStatus).")
        }
        return .notRunning
    }

    private func finish() {
        let reason = failure()
        for waiter in waiting.values {
            waiter.resume(throwing: reason)
        }
        waiting.removeAll()
        publish.finish()
        process = nil
        input = nil
    }

    private static func chunks(from handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }
    }
}
