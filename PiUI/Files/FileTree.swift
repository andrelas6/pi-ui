import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let isFolder: Bool
    var badge: String?
    var children: [FileNode]

    var id: String { path }

    /// A folder is worth opening by default when something inside it changed.
    var holdsAChange: Bool {
        badge != nil || children.contains { $0.holdsAChange }
    }
}

enum FileTree {
    /// Builds the tree from repository-relative paths. Folders come before files and
    /// both sort by name, as the design draws it.
    static func build(paths: [String], badges: [String: String] = [:]) -> [FileNode] {
        var roots: [String: Builder] = [:]

        for path in paths where !path.isEmpty {
            let parts = path.split(separator: "/").map(String.init)
            guard !parts.isEmpty else { continue }
            insert(parts, fullPath: path, into: &roots, prefix: "")
        }

        return finish(roots, badges: badges)
    }

    private final class Builder {
        let name: String
        let path: String
        var isFolder = false
        var children: [String: Builder] = [:]

        init(name: String, path: String) {
            self.name = name
            self.path = path
        }
    }

    private static func insert(
        _ parts: [String],
        fullPath: String,
        into level: inout [String: Builder],
        prefix: String
    ) {
        guard let head = parts.first else { return }
        let path = prefix.isEmpty ? head : prefix + "/" + head

        let node = level[head] ?? Builder(name: head, path: path)
        level[head] = node

        guard parts.count > 1 else { return }
        node.isFolder = true
        insert(Array(parts.dropFirst()), fullPath: fullPath, into: &node.children, prefix: path)
    }

    private static func finish(_ level: [String: Builder], badges: [String: String]) -> [FileNode] {
        level.values
            .map { node in
                FileNode(
                    name: node.name,
                    path: node.path,
                    isFolder: node.isFolder,
                    badge: node.isFolder ? nil : badges[node.path],
                    children: finish(node.children, badges: badges)
                )
            }
            .sorted { left, right in
                left.isFolder == right.isFolder
                    ? left.name.localizedStandardCompare(right.name) == .orderedAscending
                    : left.isFolder
            }
    }
}
