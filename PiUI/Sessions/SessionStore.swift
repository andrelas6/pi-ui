import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [SavedSession] = []
    private(set) var missing: Set<String> = []

    private var running: Set<String> = []
    private let file: URL

    init(file: URL = SessionStore.defaultFile) {
        self.file = file
        load()
        reconcile()
    }

    static var defaultFile: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appending(path: "pi-ui")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "sessions.json")
    }

    func remember(id: String, folder: URL, file sessionFile: URL?) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].folder = folder
            sessions[index].file = sessionFile
            sessions[index].lastOpenedAt = .now
            if let sessionFile, FileManager.default.fileExists(atPath: sessionFile.path) {
                sessions[index].everSaved = true
            }
        } else {
            let onDisk = sessionFile.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            sessions.append(
                SavedSession(
                    id: id,
                    name: nil,
                    folder: folder,
                    file: sessionFile,
                    everSaved: onDisk,
                    createdAt: .now,
                    lastOpenedAt: .now
                )
            )
        }
        missing.remove(id)
        save()
    }

    /// Newest folder first, newest session first inside each folder.
    var groups: [SessionGroup] {
        Dictionary(grouping: sessions, by: { $0.folder.path })
            .map { path, found in
                SessionGroup(
                    folder: URL(fileURLWithPath: path),
                    sessions: found.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
                )
            }
            .sorted { left, right in
                let a = left.sessions.first?.lastOpenedAt ?? .distantPast
                let b = right.sessions.first?.lastOpenedAt ?? .distantPast
                return a == b ? left.title < right.title : a > b
            }
    }

    func session(_ id: String) -> SavedSession? {
        sessions.first { $0.id == id }
    }

    func rename(_ id: String, to name: String?) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[index].name = (trimmed?.isEmpty ?? true) ? nil : trimmed
        save()
    }

    func forget(_ id: String) {
        sessions.removeAll { $0.id == id }
        missing.remove(id)
        running.remove(id)
        save()
    }

    func trash(_ id: String) throws {
        if let session = sessions.first(where: { $0.id == id }),
           let file = session.file,
           FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.trashItem(at: file, resultingItemURL: nil)
        }
        forget(id)
    }

    /// A session is only missing if it was written once and has since disappeared. pi writes
    /// the file lazily, so one that never had content is new, not lost.
    func reconcile() {
        var gone: Set<String> = []
        for index in sessions.indices {
            guard let file = sessions[index].file else { continue }
            if FileManager.default.fileExists(atPath: file.path) {
                sessions[index].everSaved = true
            } else if sessions[index].everSaved {
                gone.insert(sessions[index].id)
            }
        }
        missing = gone
        save()
    }

    func isMissing(_ id: String) -> Bool {
        missing.contains(id)
    }

    func markRunning(_ id: String) {
        running.insert(id)
    }

    func markStopped(_ id: String) {
        running.remove(id)
    }

    /// Session files have no write lock, so a second pi on the same file corrupts the tree.
    func isRunning(_ id: String) -> Bool {
        running.contains(id)
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let saved = try? JSONDecoder().decode([SavedSession].self, from: data)
        else { return }
        sessions = saved
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
