import Foundation

/// Rebuilds the transcript from pi's stored messages when a session is reopened.
enum History {
    static func messages(from stored: [JSONValue]) -> [ChatMessage] {
        var rebuilt: [ChatMessage] = []

        for message in stored {
            switch message["role"]?.string {
            case "user":
                let text = plainText(message["content"])
                guard !text.isEmpty else { continue }
                let at = Kickers.moment(fromMilliseconds: message["timestamp"]?.number)
                rebuilt.append(
                    ChatMessage(kind: .user, text: text, done: true, kicker: Kickers.user(at: at))
                )

            case "assistant":
                rebuilt.append(contentsOf: fromAssistant(message))

            case "toolResult":
                attachResult(message, to: &rebuilt)

            default:
                continue
            }
        }

        return rebuilt
    }

    private static func fromAssistant(_ message: JSONValue) -> [ChatMessage] {
        var made: [ChatMessage] = []

        for block in message["content"]?.array ?? [] {
            switch block["type"]?.string {
            case "text":
                let text = block["text"]?.string ?? ""
                guard !text.isEmpty else { continue }
                // Stored messages name the model that produced them.
                made.append(
                    ChatMessage(
                        kind: .assistant,
                        text: text,
                        done: true,
                        kicker: Kickers.agent(model: message["model"]?.string ?? "")
                    )
                )

            case "toolCall":
                guard let id = block["id"]?.string else { continue }
                let call = ChatMessage.ToolCall(
                    name: block["name"]?.string ?? "tool",
                    preview: ChatMessage.ToolCall.preview(of: block["arguments"]),
                    arguments: block["arguments"]?.prettyText ?? "",
                    output: "",
                    diff: "",
                    result: "",
                    failed: false
                )
                made.append(ChatMessage(id: id, kind: .tool, text: "", done: true, tool: call))

            // Thinking is not shown in the transcript.
            default:
                continue
            }
        }

        return made
    }

    private static func attachResult(_ message: JSONValue, to rebuilt: inout [ChatMessage]) {
        guard let id = message["toolCallId"]?.string,
              let index = rebuilt.firstIndex(where: { $0.id == id && $0.kind == .tool })
        else { return }

        rebuilt[index].tool?.output = message.contentText
        let diff = message["details"]?["diff"]?.string ?? ""
        rebuilt[index].tool?.diff = diff
        rebuilt[index].tool?.result = DiffSummary.text(diff)
        rebuilt[index].tool?.failed = message["isError"]?.bool ?? false
    }

    static func plainText(_ content: JSONValue?) -> String {
        guard let content else { return "" }
        if let text = content.string { return text }
        guard let blocks = content.array else { return "" }
        return blocks
            .filter { $0["type"]?.string == "text" }
            .compactMap { $0["text"]?.string }
            .joined()
    }
}
