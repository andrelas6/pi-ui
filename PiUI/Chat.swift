import Foundation
import Observation

@MainActor
@Observable
final class Chat {
    private(set) var folder: URL?
    private(set) var transcript = ""
    private(set) var isStreaming = false
    private(set) var problem: String?

    private var session: PiSession?
    private var eventTask: Task<Void, Never>?

    var isOpen: Bool { session != nil }

    func open(_ folder: URL) {
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
                try await session.start()
                self.session = session
                self.listen(to: session)
            } catch {
                self.problem = error.localizedDescription
            }
        }
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
        session = nil
        folder = nil
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
