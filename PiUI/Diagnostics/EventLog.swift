import Foundation

/// What the app saw, written down. Both agents are subprocesses exchanging JSON lines, and
/// until this existed every one of those lines was read once and thrown away — so a bug that
/// had already happened could only be chased by provoking it again.
///
/// Best-effort throughout: a log that can break a session is worse than no log, so nothing
/// here throws and every failure is dropped.
actor EventLog {
    enum Direction: String, Sendable {
        case into = "out"
        case from = "in"
    }

    static let shared = EventLog()

    /// Keeps a busy week from filling the disk. Total size rather than a file count, because
    /// one heavy day dwarfs a quiet fortnight.
    static let cap = 20 * 1024 * 1024

    private let folder: URL
    private var handle: FileHandle?
    private var openFor: String?
    private var pruned = false

    init(folder: URL = EventLog.defaultFolder) {
        self.folder = folder
    }

    static var defaultFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "pi-ui").appending(path: "logs")
    }

    /// One line the app and an agent exchanged.
    func wire(_ channel: String, _ direction: Direction, _ body: JSONValue) {
        write([
            "kind": .string("wire"),
            "channel": .string(channel),
            "dir": .string(direction.rawValue),
            "body": Clip.value(body),
        ])
    }

    /// Something that happened to an agent process: spawned, said something on stderr, exited.
    func life(_ channel: String, _ event: String, _ detail: [String: JSONValue] = [:]) {
        var record: [String: JSONValue] = [
            "kind": .string("life"),
            "channel": .string(channel),
            "event": .string(event),
        ]
        record.merge(detail.mapValues { Clip.value($0) }) { current, _ in current }
        write(record)
    }

    /// A decision the app made, for correlating against the wire around it.
    func app(_ event: String, _ detail: [String: JSONValue] = [:]) {
        var record: [String: JSONValue] = [
            "kind": .string("app"),
            "event": .string(event),
        ]
        record.merge(detail.mapValues { Clip.value($0) }) { current, _ in current }
        write(record)
    }

    var directory: URL { folder }

    func purge() {
        try? handle?.close()
        handle = nil
        openFor = nil
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.pathExtension == "jsonl" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Oldest first, until the directory is back under the cap. Called once per launch —
    /// a day's file is only closed at midnight, so there is nothing to reclaim in between.
    func prune(cap: Int = EventLog.cap) {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys
        ))?.filter { $0.pathExtension == "jsonl" } ?? []

        let sized = files.compactMap { file -> (URL, Int, Date)? in
            guard let values = try? file.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize,
                  let changed = values.contentModificationDate
            else { return nil }
            return (file, size, changed)
        }

        var total = sized.reduce(0) { $0 + $1.1 }
        guard total > cap else { return }

        for (file, size, _) in sized.sorted(by: { $0.2 < $1.2 }) {
            guard total > cap else { break }
            // Never delete the file being written to; it is the one worth having.
            guard file.lastPathComponent != Self.name(for: Date()) else { continue }
            try? FileManager.default.removeItem(at: file)
            total -= size
        }
    }

    private func write(_ fields: [String: JSONValue]) {
        var record = fields
        record["at"] = .string(Self.stamp.format(Date()))

        guard let line = try? JSONEncoder().encode(JSONValue.object(record)) else { return }
        guard let handle = handle(for: Date()) else { return }

        try? handle.write(contentsOf: line)
        try? handle.write(contentsOf: Data([0x0A]))
    }

    /// A file per day. Reopened when the day turns over, so a long-running app does not keep
    /// writing yesterday's file.
    private func handle(for moment: Date) -> FileHandle? {
        let wanted = Self.name(for: moment)
        if openFor == wanted, let handle {
            return handle
        }

        try? handle?.close()
        handle = nil
        openFor = nil

        let manager = FileManager.default
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)

        if !pruned {
            pruned = true
            prune()
        }

        let file = folder.appending(path: wanted)
        if !manager.fileExists(atPath: file.path) {
            manager.createFile(atPath: file.path, contents: nil)
        }
        guard let opened = try? FileHandle(forWritingTo: file) else { return nil }
        try? opened.seekToEnd()

        handle = opened
        openFor = wanted
        return opened
    }

    static func name(for moment: Date) -> String {
        "piui-\(day.format(moment)).jsonl"
    }

    /// UTC throughout, so a log read on another machine lines up with this one. Format styles
    /// rather than the older formatters, which are not `Sendable`.
    private static let day = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    private static let stamp = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true,
        timeZone: .gmt
    )
}
