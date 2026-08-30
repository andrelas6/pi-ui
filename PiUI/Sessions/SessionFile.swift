import Foundation

/// A pi session on disk. The header carries `cwd` verbatim, which is the only reliable
/// source: the folder name it lives in replaces every "/" with "-", so "a/b" and "a-b"
/// encode identically and cannot be told apart afterwards.
struct SessionFile: Equatable, Sendable {
    let id: String
    let folder: URL
    let startedAt: Date?
    let name: String?

    static func read(_ url: URL) -> SessionFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> SessionFile? {
        var buffer = LineBuffer()
        let lines = buffer.take(data)
        guard let first = lines.first,
              let header = try? JSONDecoder().decode(JSONValue.self, from: first),
              header["type"]?.string == "session",
              let id = header["id"]?.string,
              let cwd = header["cwd"]?.string
        else { return nil }

        var name: String?
        for line in lines.dropFirst() {
            guard let entry = try? JSONDecoder().decode(JSONValue.self, from: line),
                  entry["type"]?.string == "session_info"
            else { continue }
            name = entry["name"]?.string
        }

        return SessionFile(
            id: id,
            folder: URL(fileURLWithPath: cwd),
            startedAt: header["timestamp"]?.string.flatMap(parseDate),
            name: name
        )
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
