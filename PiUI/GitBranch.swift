import Foundation

/// Reads the current branch by shelling out to git. No git library: the answer is one
/// short command, and a dependency would cost more than it saves.
enum GitBranch {
    static func name(in folder: URL) -> String? {
        clean(Git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: folder) ?? "")
    }

    static func clean(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        // A repo sitting on a detached HEAD reports this rather than a name.
        guard name != "HEAD" else { return nil }
        return name
    }
}
