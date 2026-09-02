import Foundation

struct SavedSession: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String?
    var folder: URL
    var file: URL?
    var everSaved: Bool
    var createdAt: Date
    var lastOpenedAt: Date

    var agent: Agent = .pi

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

/// Indexes written before Claude sessions existed have no agent, and every session in one
/// of those was pi. Resolving it here means nothing downstream handles the absence.
///
/// This lives in an extension so the memberwise initialiser survives — writing it inside the
/// struct would suppress the one `SessionStore.remember` uses.
extension SavedSession {
    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        id = try fields.decode(String.self, forKey: .id)
        name = try fields.decodeIfPresent(String.self, forKey: .name)
        folder = try fields.decode(URL.self, forKey: .folder)
        file = try fields.decodeIfPresent(URL.self, forKey: .file)
        everSaved = try fields.decode(Bool.self, forKey: .everSaved)
        createdAt = try fields.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try fields.decode(Date.self, forKey: .lastOpenedAt)
        agent = try fields.decodeIfPresent(Agent.self, forKey: .agent) ?? .pi
    }
}
