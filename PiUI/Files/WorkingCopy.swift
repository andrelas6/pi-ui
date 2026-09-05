import Foundation

/// What the file pane shows: the tracked tree, what changed, and the totals.
struct WorkingCopy: Sendable {
    var nodes: [FileNode] = []
    var paths: [String] = []
    var changed = 0
    var added = 0
    var removed = 0

    var isEmpty: Bool { nodes.isEmpty }

    var tallyText: String {
        guard added > 0 || removed > 0 else { return "" }
        return "+\(added) −\(removed)"
    }

    var changedText: String {
        changed == 1 ? "1 changed" : "\(changed) changed"
    }

    /// Built from what git tracks plus anything untracked it would not ignore, so
    /// build folders and vendored dependencies never reach the pane.
    static func read(_ folder: URL) -> WorkingCopy {
        guard let tracked = Git.run(["ls-files"], in: folder) else { return WorkingCopy() }

        let porcelain = Git.run(["status", "--porcelain"], in: folder) ?? ""
        let badges = GitStatus.badges(porcelain: porcelain)
        let untracked = badges.keys.filter { !$0.hasSuffix("/") }

        var paths = Set(tracked.split(separator: "\n").map(String.init))
        paths.formUnion(untracked)

        let shortstat = Git.run(["diff", "--shortstat", "HEAD"], in: folder) ?? ""
        let tally = GitStatus.tally(shortstat: shortstat)

        let pathsList = Array(paths)
        return WorkingCopy(
            nodes: FileTree.build(paths: pathsList, badges: badges),
            paths: pathsList.sorted(),
            changed: badges.count,
            added: tally.added,
            removed: tally.removed
        )
    }
}
