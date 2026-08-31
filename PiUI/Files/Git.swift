import Foundation

/// One place that shells out to git, so the callers stay about what they asked for.
enum Git {
    static func run(_ arguments: [String], in folder: URL) -> String? {
        guard FileManager.default.fileExists(atPath: folder.appending(path: ".git").path)
        else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", folder.path] + arguments
        process.environment = ProcessInfo.processInfo.environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        return String(decoding: data, as: UTF8.self)
    }
}

enum GitStatus {
    /// Porcelain lines are a two-character status, a space, then the path — so the
    /// status cannot be read by splitting on whitespace.
    static func badges(porcelain: String) -> [String: String] {
        var found: [String: String] = [:]

        for line in porcelain.split(separator: "\n") {
            guard line.count > 3 else { continue }
            let marks = String(line.prefix(2))
            let path = unquote(String(line.dropFirst(3)))
            guard !path.isEmpty else { continue }

            // A rename reads "old -> new"; the new name is the one in the tree.
            let named = path.components(separatedBy: " -> ").last ?? path
            found[named] = badge(marks)
        }

        return found
    }

    static func badge(_ marks: String) -> String {
        if marks == "??" { return "A" }
        if marks.contains("R") { return "R" }
        if marks.contains("A") { return "A" }
        if marks.contains("D") { return "D" }
        if marks.contains("M") { return "M" }
        return "M"
    }

    /// " 3 files changed, 41 insertions(+), 7 deletions(-)" — either half may be absent.
    static func tally(shortstat: String) -> (added: Int, removed: Int) {
        (number(before: "insertion", in: shortstat), number(before: "deletion", in: shortstat))
    }

    private static func number(before word: String, in text: String) -> Int {
        for part in text.components(separatedBy: ",") {
            guard part.contains(word) else { continue }
            let digits = part.filter(\.isNumber)
            return Int(digits) ?? 0
        }
        return 0
    }

    /// git quotes paths containing unusual characters.
    private static func unquote(_ path: String) -> String {
        guard path.hasPrefix("\""), path.hasSuffix("\""), path.count > 1 else { return path }
        return String(path.dropFirst().dropLast())
    }
}
