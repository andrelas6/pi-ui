import Foundation

/// Turns ACP `session/update` notifications into the events `Chat.handle` already reads.
/// Keeping the app's vocabulary means the transcript, tool cards and diff rendering work
/// for Claude without knowing ACP exists.
///
/// Pure and stateful only in the small ways streaming needs: which assistant message is
/// open, so a new one starts a new bubble.
struct AcpEvents {
    private var openMessageId: String?

    /// ACP streams text as chunks tagged with a message id. pi announces a start and an
    /// end, so those are synthesised here when the id changes.
    mutating func translate(_ message: JSONValue) -> [JSONValue] {
        guard message["method"]?.string == "session/update",
              let update = message["params"]?["update"]
        else { return [] }

        switch update["sessionUpdate"]?.string {
        case "agent_message_chunk":
            return text(from: update)

        case "user_message_chunk":
            return replayedUser(update)

        case "tool_call":
            return closingOpenMessage() + [toolStart(update)]

        case "tool_call_update":
            return [toolUpdate(update)]

        // Thinking is not shown in the transcript, and plans, commands, usage and mode
        // changes have nowhere to go in this UI yet.
        default:
            return []
        }
    }

    /// The turn is over: close anything still open.
    mutating func settle() -> [JSONValue] {
        closeMessage() + [.object(["type": .string("agent_settled")])]
    }

    /// Closes the open message without ending a turn. Replaying a loaded session streams
    /// its history and then simply stops — the last answer would otherwise stay open, and
    /// an open message is drawn as raw streaming text rather than parsed markdown.
    mutating func closeMessage() -> [JSONValue] {
        closingOpenMessage()
    }

    /// A prompt the app sent. ACP does not echo it back, so the transcript would lose the
    /// user's own words without this.
    static func userMessage(_ text: String) -> JSONValue {
        .object([
            "type": .string("message_start"),
            "message": .object([
                "role": .string("user"),
                "content": .string(text),
                "timestamp": .number(Date().timeIntervalSince1970 * 1000),
            ]),
        ])
    }

    private mutating func text(from update: JSONValue) -> [JSONValue] {
        let chunk = update["content"]?["text"]?.string ?? ""
        guard !chunk.isEmpty else { return [] }

        let id = update["messageId"]?.string ?? openMessageId ?? "message"
        var events: [JSONValue] = []

        if openMessageId != id {
            events += closingOpenMessage()
            events.append(part("text_start"))
            openMessageId = id
        }

        events.append(part("text_delta", ["delta": .string(chunk)]))
        return events
    }

    /// Replaying a loaded session hands back the user's turns too.
    private mutating func replayedUser(_ update: JSONValue) -> [JSONValue] {
        let chunk = update["content"]?["text"]?.string ?? ""
        guard !chunk.isEmpty else { return [] }
        return closingOpenMessage() + [Self.userMessage(chunk)]
    }

    private mutating func closingOpenMessage() -> [JSONValue] {
        guard openMessageId != nil else { return [] }
        openMessageId = nil
        return [part("text_end")]
    }

    private func part(_ kind: String, _ extra: [String: JSONValue] = [:]) -> JSONValue {
        var event: [String: JSONValue] = ["type": .string(kind)]
        event.merge(extra) { _, new in new }
        return .object([
            "type": .string("message_update"),
            "assistantMessageEvent": .object(event),
        ])
    }

    /// A call is announced before its arguments are known — `rawInput` is `{}` here and
    /// fills in over later updates — so an empty one is left out rather than shown as `{}`.
    private func toolStart(_ update: JSONValue) -> JSONValue {
        var event: [String: JSONValue] = [
            "type": .string("tool_execution_start"),
            "toolCallId": .string(update["toolCallId"]?.string ?? ""),
            "toolName": .string(Self.name(of: update)),
        ]
        if let args = Self.arguments(in: update) {
            event["args"] = args
        }
        return .object(event)
    }

    private func toolUpdate(_ update: JSONValue) -> JSONValue {
        let id = update["toolCallId"]?.string ?? ""
        let status = update["status"]?.string ?? ""

        var event: [String: JSONValue] = ["toolCallId": .string(id)]
        // Arguments and the diff both arrive on these updates rather than on the call, and
        // the update that finally says "completed" carries neither.
        if let args = Self.arguments(in: update) {
            event["args"] = args
        }
        let patch = Self.diff(in: update)
        if !patch.isEmpty {
            event["diff"] = .string(patch)
        }

        guard status == "completed" || status == "failed" else {
            event["type"] = .string("tool_execution_update")
            event["partialResult"] = .object(["content": .array(Self.textBlocks(in: update))])
            return .object(event)
        }

        event["type"] = .string("tool_execution_end")
        event["isError"] = .bool(status == "failed")
        event["result"] = .object([
            "content": .array(Self.textBlocks(in: update)),
            "details": .object(["diff": .string(patch)]),
        ])
        return .object(event)
    }

    /// Claude Code names the real tool in its own metadata; the ACP title is a sentence
    /// ("Write hello.txt"), which reads badly as a tool name on the card.
    static func name(of update: JSONValue) -> String {
        if let tool = update["_meta"]?["claudeCode"]?["toolName"]?.string, !tool.isEmpty {
            return tool
        }
        return update["title"]?.string ?? "tool"
    }

    /// Only worth passing on once it says something; the last update drops `rawInput`
    /// altogether, and an empty one must not wipe what earlier updates established.
    static func arguments(in update: JSONValue) -> JSONValue? {
        guard let raw = update["rawInput"],
              case .object(let fields) = raw,
              !fields.isEmpty
        else { return nil }
        return raw
    }

    static func textBlocks(in update: JSONValue) -> [JSONValue] {
        (update["content"]?.array ?? []).compactMap { block in
            guard block["type"]?.string == "content",
                  let text = block["content"]?["text"]?.string,
                  !text.isEmpty
            else { return nil }
            return .object(["type": .string("text"), "text": .string(text)])
        }
    }

    /// The adapter's `structuredPatch` is already unified-diff lines, which is exactly what
    /// the transcript renders and `DiffSummary` counts. The portable ACP diff block carries
    /// only before and after, so that is turned into the same shape.
    static func diff(in update: JSONValue) -> String {
        let hunks = update["_meta"]?["claudeCode"]?["toolResponse"]?["structuredPatch"]?.array ?? []
        let patch = hunks
            .flatMap { $0["lines"]?.array ?? [] }
            .compactMap(\.string)
        if !patch.isEmpty {
            return patch.joined(separator: "\n")
        }

        guard let block = (update["content"]?.array ?? []).first(where: {
            $0["type"]?.string == "diff"
        }) else { return "" }

        // A created file has no `oldText` at all, which is a whole-file addition.
        let old = block["oldText"]?.string ?? ""
        let new = block["newText"]?.string ?? ""
        guard old != new else { return "" }

        let removed = Self.lines(of: old).map { "-\($0)" }
        let added = Self.lines(of: new).map { "+\($0)" }
        return (removed + added).joined(separator: "\n")
    }

    /// A trailing newline ends the last line rather than starting an empty one, and an
    /// empty row of "+" in the diff is just noise.
    static func lines(of text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var found = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if found.last == "" {
            found.removeLast()
        }
        return found
    }
}
