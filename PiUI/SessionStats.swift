import Foundation

struct SessionStats: Equatable, Sendable {
    var tokens: Int
    var contextWindow: Int
    var percent: Int
    var cost: Double

    init?(_ response: JSONValue) {
        guard let data = response["data"] else { return nil }
        cost = data["cost"]?.number ?? 0

        // Missing right after compaction, and absent when no model is set.
        let usage = data["contextUsage"]
        tokens = Int(usage?["tokens"]?.number ?? 0)
        contextWindow = Int(usage?["contextWindow"]?.number ?? 0)
        percent = Int(usage?["percent"]?.number ?? 0)
    }

    var costText: String {
        guard cost > 0 else { return "" }
        return cost < 0.01 ? "<$0.01" : String(format: "$%.2f", cost)
    }

    var contextText: String? {
        guard contextWindow > 0 else { return nil }
        return "\(percent)%"
    }

    /// Worth warning about before starting a long turn.
    var isTight: Bool {
        contextWindow > 0 && percent >= 75
    }
}
