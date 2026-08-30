import Foundation

/// A question pi's extension layer is waiting on. Nothing proceeds until it is answered.
struct Ask: Identifiable, Equatable, Sendable {
    enum Method: String, Sendable {
        case confirm
        case select
        case input
        case editor
    }

    let id: String
    let method: Method
    let title: String
    let message: String
    let options: [String]
    let prefill: String
    let placeholder: String

    init?(_ event: JSONValue) {
        guard let id = event["id"]?.string,
              let raw = event["method"]?.string,
              let method = Method(rawValue: raw)
        else { return nil }

        self.id = id
        self.method = method
        title = event["title"]?.string ?? "pi is asking"
        message = event["message"]?.string ?? ""
        options = event["options"]?.array?.compactMap(\.string) ?? []
        prefill = event["prefill"]?.string ?? ""
        placeholder = event["placeholder"]?.string ?? ""
    }
}
