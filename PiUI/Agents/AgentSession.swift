import Foundation

/// What a session tells the app once it is open and rehydrated.
struct OpenedSession: Sendable {
    var id: String
    var file: URL?
    var modelName: String = ""
    var thinkingLevel: String = ""
    var messages: [ChatMessage] = []
}

/// How a permission card was answered. "Always" is remembered by the app for the window
/// either way; agents that can remember it themselves are told so too.
enum PermissionChoice: Sendable {
    case allow
    case always
    case deny
}

/// The conversation operations every agent has to support. Events arrive as the app's own
/// vocabulary — pi emits it directly, and the ACP adapter is translated into it — so
/// `Chat.handle` reads the same shapes whichever agent is running.
///
/// Model pickers, thinking levels, commands and stats are not here: they are pi-only for
/// now and `Chat` reaches for the pi session directly to load them.
protocol AgentSession: Sendable {
    var events: AsyncStream<JSONValue> { get }

    func open(sessionId: String?) async throws -> OpenedSession
    func stop() async

    func prompt(_ text: String) async throws
    func steer(_ text: String, followUp: Bool) async throws
    func abort() async throws

    /// Returns whatever was still queued, so the composer can offer it back.
    func clearQueue() async throws -> [String]

    func answer(id: String, choice: PermissionChoice) async throws
    func answer(id: String, value: String) async throws
    func dismiss(id: String) async throws

    func rename(to name: String) async throws
}
