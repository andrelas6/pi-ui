import Foundation

/// The small uppercase label above each message: "YOU · 14:02", "AGENT · OPUS 4.6".
/// Built in Swift so the page only has to print it.
enum Kickers {
    static func user(at moment: Date) -> String {
        "YOU · \(time(moment))"
    }

    static func agent(model: String) -> String {
        let name = model.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "AGENT" : "AGENT · \(name.uppercased())"
    }

    static func time(_ moment: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: moment)
    }

    /// pi stores message times as epoch milliseconds.
    static func moment(fromMilliseconds value: Double?) -> Date {
        guard let value, value > 0 else { return .now }
        return Date(timeIntervalSince1970: value / 1000)
    }
}

/// A tool row ends with a short result. A diff can say how much it changed; most
/// tools cannot say anything honest in three words, so they say nothing.
enum DiffSummary {
    static func count(_ diff: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            switch line.first {
            case "+": added += 1
            case "-": removed += 1
            default: continue
            }
        }
        return (added, removed)
    }

    static func text(_ diff: String) -> String {
        guard !diff.isEmpty else { return "" }
        let tally = count(diff)
        guard tally.added > 0 || tally.removed > 0 else { return "" }
        return "+\(tally.added) −\(tally.removed)"
    }
}
