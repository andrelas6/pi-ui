import Foundation

/// Something you can invoke by typing `/name`: an extension command, a prompt
/// template, or a skill.
struct PiCommand: Identifiable, Hashable, Sendable {
    let name: String
    let detail: String
    let source: String
    let path: String?

    var id: String { name }

    /// Skills arrive already prefixed as `skill:tidy-imports`; the prefix is noise in
    /// a list that already says where each command came from.
    var title: String {
        name.hasPrefix("skill:") ? String(name.dropFirst("skill:".count)) : name
    }

    var kind: String {
        switch source {
        case "skill": "skill"
        case "prompt": "template"
        default: "command"
        }
    }

    init?(_ value: JSONValue) {
        guard let name = value["name"]?.string, !name.isEmpty else { return nil }
        self.name = name
        detail = value["description"]?.string ?? ""
        source = value["source"]?.string ?? "extension"
        // Installed pi nests this under sourceInfo; the docs show it at the top level.
        path = value["sourceInfo"]?["path"]?.string ?? value["path"]?.string
    }

    static func all(from response: JSONValue) -> [PiCommand] {
        let found = (response["data"]?["commands"]?.array ?? []).compactMap(PiCommand.init)
        return found.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func matches(_ search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        let haystack = "\(name) \(detail) \(kind)".lowercased()
        return needle.split(separator: " ").allSatisfy { haystack.contains($0) }
    }
}
