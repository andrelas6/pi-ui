import Foundation

/// Which coding agent a session runs on. pi is driven over its own JSONL protocol;
/// Claude is driven over ACP through an adapter.
enum Agent: String, Codable, CaseIterable, Sendable {
    case pi
    case claude

    var name: String {
        switch self {
        case .pi: "pi"
        case .claude: "Claude"
        }
    }

    var newSessionTitle: String {
        "New \(name) session…"
    }
}
