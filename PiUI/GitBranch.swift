import Foundation

/// Reads the current branch by shelling out to git. No git library: the answer is one
/// short command, and a dependency would cost more than it saves.
enum GitBranch {
    static func name(in folder: URL) -> String? {
        guard FileManager.default.fileExists(atPath: folder.appending(path: ".git").path)
        else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", folder.path, "rev-parse", "--abbrev-ref", "HEAD"]
        process.environment = ProcessInfo.processInfo.environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        return clean(String(decoding: data, as: UTF8.self))
    }

    static func clean(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        // A repo sitting on a detached HEAD reports this rather than a name.
        guard name != "HEAD" else { return nil }
        return name
    }
}
