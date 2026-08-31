import Foundation

struct ModelChoice: Identifiable, Hashable, Sendable {
    let provider: String
    let modelId: String
    let name: String
    let contextWindow: Int
    let costPerMillionIn: Double
    let costPerMillionOut: Double

    var id: String { "\(provider)/\(modelId)" }

    init?(_ value: JSONValue) {
        guard let provider = value["provider"]?.string,
              let modelId = value["id"]?.string
        else { return nil }

        self.provider = provider
        self.modelId = modelId
        name = value["name"]?.string ?? modelId
        contextWindow = Int(value["contextWindow"]?.number ?? 0)
        costPerMillionIn = value["cost"]?["input"]?.number ?? 0
        costPerMillionOut = value["cost"]?["output"]?.number ?? 0
    }

    static func all(from response: JSONValue) -> [ModelChoice] {
        (response["data"]?["models"]?.array ?? []).compactMap(ModelChoice.init)
    }

    /// Matches on the whole "provider/id" plus the display name, so "claude sonnet"
    /// and "anthropic/claude" both land.
    func matches(_ search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        let haystack = "\(id) \(name)".lowercased()
        return needle.split(separator: " ").allSatisfy { haystack.contains($0) }
    }
}
