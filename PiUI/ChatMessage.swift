import Foundation

struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case user
        case assistant
        case tool
    }

    struct ToolCall: Codable, Hashable, Sendable {
        var name: String
        var preview: String
        var arguments: String
        var output: String
        var diff: String
        var result: String
        var failed: Bool

        /// The one detail worth showing on the collapsed card, per tool.
        static func preview(of args: JSONValue?) -> String {
            for key in ["command", "path", "file_path", "pattern", "query"] {
                if let value = args?[key]?.string, !value.isEmpty {
                    return value
                }
            }
            return ""
        }
    }

    let id: String
    var kind: Kind
    var text: String
    var done: Bool
    var kicker: String
    var tool: ToolCall?

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        text: String,
        done: Bool,
        kicker: String = "",
        tool: ToolCall? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.done = done
        self.kicker = kicker
        self.tool = tool
    }
}
