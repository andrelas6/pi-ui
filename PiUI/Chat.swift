import Foundation
import Observation

@MainActor
@Observable
final class Chat {
    private(set) var folder: URL?
    private(set) var transcript = ""
    private(set) var isStreaming = false
    private(set) var problem: String?
    private(set) var openSessionId: String?

    private let store: SessionStore
    private var session: PiSession?
    private var eventTask: Task<Void, Never>?

    init(store: SessionStore) {
        self.store = store
    }

    var isOpen: Bool { session != nil }

    func reopen(_ saved: SavedSession) {
        guard !store.isRunning(saved.id) else { return }
        open(saved.folder, sessionId: saved.id)
    }

    func open(_ folder: URL, sessionId: String? = nil) {
        close()

        let executable: URL
        do {
            executable = try PiPath.fromEnvironment()
        } catch {
            problem = error.localizedDescription
            return
        }

        let session = PiSession(executable: executable, folder: folder)
        self.folder = folder
        problem = nil
        transcript = ""

        Task {
            do {
                let arguments = sessionId.map { ["--session-id", $0] } ?? []
                try await session.start(arguments: arguments)
                self.session = session
                self.listen(to: session)
                try await self.rememberSession(session, folder: folder)
            } catch {
                self.problem = error.localizedDescription
            }
        }
    }

    private func rememberSession(_ session: PiSession, folder: URL) async throws {
        let state = try await session.send("get_state")
        guard let id = state["data"]?["sessionId"]?.string else { return }
        let file = state["data"]?["sessionFile"]?.string.map { URL(fileURLWithPath: $0) }
        openSessionId = id
        store.remember(id: id, folder: folder, file: file)
        store.markRunning(id)
    }

    func send(_ text: String) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let session else { return }

        transcript += "› \(message)\n\n"
        isStreaming = true

        Task {
            do {
                try await session.send("prompt", fields: ["message": .string(message)])
            } catch {
                problem = error.localizedDescription
                isStreaming = false
            }
        }
    }

    func stop() {
        guard let session else { return }
        Task { try? await session.send("abort") }
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
        folder = nil
        openSessionId = nil
        isStreaming = false
    }

    private func listen(to session: PiSession) {
        eventTask = Task { [weak self] in
            for await event in session.events {
                self?.handle(event)
            }
        }
    }

    func handle(_ event: JSONValue) {
        switch event["type"]?.string {
        case "message_update":
            guard let update = event["assistantMessageEvent"],
                  update["type"]?.string == "text_delta",
                  let delta = update["delta"]?.string
            else { return }
            transcript += delta

        case "tool_execution_start":
            // Without this a tool-using turn looks frozen. Real cards come in S7.
            if let name = event["toolName"]?.string {
                transcript += "\n[\(name)]\n"
            }

        case "message_end":
            guard let message = event["message"],
                  message["role"]?.string == "assistant",
                  message["stopReason"]?.string == "error"
            else { return }
            problem = Self.readable(message["errorMessage"]?.string)
            isStreaming = false

        case "agent_settled":
            isStreaming = false
            transcript += "\n\n"
            store.reconcile()

        default:
            break
        }
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
