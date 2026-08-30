import Foundation

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

    private var process: Process?
    private var input: FileHandle?
    private var buffer = LineBuffer()
    private var waiting: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var counter = 0
    private var readTask: Task<Void, Never>?
    private var errorOutput = ""

    let events: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    init(executable: URL, folder: URL) {
        self.executable = executable
        self.folder = folder
        (events, publish) = AsyncStream.makeStream()
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    var stderrText: String {
        errorOutput
    }

    func start(arguments: [String] = []) throws {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--mode", "rpc"] + arguments
        process.currentDirectoryURL = folder
        process.environment = childEnvironment()

        let toPi = Pipe()
        let fromPi = Pipe()
        let errors = Pipe()
        process.standardInput = toPi
        process.standardOutput = fromPi
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw Failure.couldNotStart(error.localizedDescription)
        }

        self.process = process
        self.input = toPi.fileHandleForWriting

        let output = fromPi.fileHandleForReading
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
    func send(_ type: String, fields: [String: JSONValue] = [:]) async throws -> JSONValue {
        guard let input else { throw Failure.notRunning }

        counter += 1
        let id = "r\(counter)"
        var payload = fields
        payload["type"] = .string(type)
        payload["id"] = .string(id)

        let line = try JSONEncoder().encode(JSONValue.object(payload))

        return try await withCheckedThrowingContinuation { continuation in
            waiting[id] = continuation
            do {
                try input.write(contentsOf: line)
                try input.write(contentsOf: Data([0x0A]))
            } catch {
                waiting.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }

    /// Extension UI replies carry the request's own id and get no response back,
    /// so they cannot go through `send`.
    func post(_ fields: [String: JSONValue]) throws {
        guard let input else { throw Failure.notRunning }
        let line = try JSONEncoder().encode(JSONValue.object(fields))
        try input.write(contentsOf: line)
        try input.write(contentsOf: Data([0x0A]))
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        try? input?.close()
        process?.terminate()
        finish()
    }

    private func handle(_ chunk: Data) {
        for line in buffer.take(chunk) {
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: line) else { continue }
            route(value)
        }
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

    private func collectError(_ chunk: Data) {
        errorOutput += String(decoding: chunk, as: UTF8.self)
    }

    private func finish() {
        for waiter in waiting.values {
            waiter.resume(throwing: Failure.notRunning)
        }
        waiting.removeAll()
        publish.finish()
        process = nil
        input = nil
    }

    private func childEnvironment() -> [String: String] {
        Self.environment(for: executable, base: ProcessInfo.processInfo.environment)
    }

    /// pi's shebang runs `env node`, and node sits in pi's own bin directory. A GUI app
    /// inherits a PATH with neither on it, so prepend that directory. Do not resolve the
    /// symlink first — that lands in the package, where node is not.
    static func environment(for executable: URL, base: [String: String]) -> [String: String] {
        var environment = base
        let binDirectory = executable.deletingLastPathComponent().path
        let inherited = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = binDirectory + ":" + inherited
        return environment
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
