import Foundation

/// A child agent, spoken to in JSON lines. Both agents are subprocesses that read and write
/// one JSON object per line; only what those objects mean differs, so the spawning, the
/// framing and the stderr collection live here once.
actor AgentProcess {
    enum Failure: Error {
        case notRunning
        case couldNotStart(String)
    }

    private let executable: URL
    private let arguments: [String]
    private let folder: URL

    private var process: Process?
    private var input: FileHandle?
    private var buffer = LineBuffer()
    private var readTask: Task<Void, Never>?
    private var errors = ""
    private var status: Int32?

    /// One value per line the agent writes. Finishes when the agent's output closes.
    nonisolated let lines: AsyncStream<JSONValue>
    private let publish: AsyncStream<JSONValue>.Continuation

    init(executable: URL, arguments: [String], folder: URL) {
        self.executable = executable
        self.arguments = arguments
        self.folder = folder
        (lines, publish) = AsyncStream.makeStream()
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// What the agent said on the way down. An agent that dies on launch explains itself
    /// here and nowhere else.
    var stderrText: String {
        errors.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var exitStatus: Int32? {
        status
    }

    func start() throws {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.environment = Self.environment(
            for: executable,
            base: ProcessInfo.processInfo.environment
        )

        let toAgent = Pipe()
        let fromAgent = Pipe()
        let stderr = Pipe()
        process.standardInput = toAgent
        process.standardOutput = fromAgent
        process.standardError = stderr

        process.terminationHandler = { [weak self] finished in
            let code = finished.terminationStatus
            Task { await self?.noteExit(code) }
        }

        do {
            try process.run()
        } catch {
            throw Failure.couldNotStart(error.localizedDescription)
        }

        self.process = process
        self.input = toAgent.fileHandleForWriting

        let output = fromAgent.fileHandleForReading
        readTask = Task { [weak self] in
            for await chunk in Self.chunks(from: output) {
                await self?.take(chunk)
            }
            await self?.finish()
        }

        let errorHandle = stderr.fileHandleForReading
        Task { [weak self] in
            for await chunk in Self.chunks(from: errorHandle) {
                await self?.collect(chunk)
            }
        }
    }

    func write(_ value: JSONValue) throws {
        guard let input else { throw Failure.notRunning }
        try input.write(contentsOf: JSONEncoder().encode(value))
        try input.write(contentsOf: Data([0x0A]))
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        try? input?.close()
        process?.terminate()
        finish()
    }

    /// pi's shebang runs `env node`, and node sits in pi's own bin directory; the ACP adapter
    /// is the same shape. A GUI app inherits a PATH with neither on it, so prepend that
    /// directory. Do not resolve the symlink first — that lands in the package, where node
    /// is not.
    static func environment(for executable: URL, base: [String: String]) -> [String: String] {
        var environment = base
        let binDirectory = executable.deletingLastPathComponent().path
        let inherited = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = binDirectory + ":" + inherited
        return environment
    }

    private func take(_ chunk: Data) {
        for line in buffer.take(chunk) {
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: line) else { continue }
            publish.yield(value)
        }
    }

    private func collect(_ chunk: Data) {
        errors += String(decoding: chunk, as: UTF8.self)
    }

    private func noteExit(_ code: Int32) {
        status = code
    }

    private func finish() {
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
