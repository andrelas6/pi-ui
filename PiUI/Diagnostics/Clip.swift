import Foundation

/// Keeps a value's shape while dropping its bulk. A log is read for structure — which field
/// was empty, which status arrived — and a file's whole contents in the middle of that is
/// noise that also fills the disk.
enum Clip {
    static let limit = 2048

    static func value(_ value: JSONValue, limit: Int = Clip.limit) -> JSONValue {
        switch value {
        case .string(let text):
            guard text.count > limit else { return value }
            return .string("‹clipped \(text.count) chars›")

        case .array(let items):
            return .array(items.map { Self.value($0, limit: limit) })

        case .object(let fields):
            return .object(fields.mapValues { Self.value($0, limit: limit) })

        case .null, .bool, .number:
            return value
        }
    }
}
