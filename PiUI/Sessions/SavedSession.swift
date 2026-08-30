import Foundation

struct SavedSession: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String?
    var folder: URL
    var file: URL?
    var everSaved: Bool
    var createdAt: Date
    var lastOpenedAt: Date

    var title: String {
        if let name, !name.isEmpty { return name }
        return folder.lastPathComponent
    }
}

struct SessionGroup: Identifiable, Hashable, Sendable {
    let folder: URL
    let sessions: [SavedSession]

    var id: String { folder.path }
    var title: String { folder.lastPathComponent }
}
