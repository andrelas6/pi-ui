import Foundation

struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case user
        case assistant
        case tool
    }

    let id: String
    var kind: Kind
    var text: String
    var done: Bool

    init(id: String = UUID().uuidString, kind: Kind, text: String, done: Bool) {
        self.id = id
        self.kind = kind
        self.text = text
        self.done = done
    }
}
