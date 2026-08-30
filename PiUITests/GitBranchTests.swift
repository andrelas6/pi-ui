import Foundation
import Testing

@testable import PiUI

struct GitBranchTests {
    private func run(_ arguments: [String], in folder: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func newRepo() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        run(["git", "init", "-b", "main"], in: folder)
        run(["git", "config", "user.email", "test@example.com"], in: folder)
        run(["git", "config", "user.name", "Test"], in: folder)
        try Data("hello\n".utf8).write(to: folder.appending(path: "a.txt"))
        run(["git", "add", "a.txt"], in: folder)
        run(["git", "commit", "-m", "first"], in: folder)
        return folder
    }

    @Test func readsTheCurrentBranch() throws {
        let repo = try newRepo()
        #expect(GitBranch.name(in: repo) == "main")
    }

    @Test func followsABranchChange() throws {
        let repo = try newRepo()
        run(["git", "checkout", "-b", "feature/thing"], in: repo)
        #expect(GitBranch.name(in: repo) == "feature/thing")
    }

    @Test func returnsNothingOutsideARepo() throws {
        let plain = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-plain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

        #expect(GitBranch.name(in: plain) == nil)
    }

    @Test func returnsNothingForAMissingFolder() {
        let gone = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-gone-\(UUID().uuidString)")
        #expect(GitBranch.name(in: gone) == nil)
    }

    /// A detached HEAD reports "HEAD", which is not a branch name worth showing.
    @Test func treatsDetachedHeadAsNoBranch() {
        #expect(GitBranch.clean("HEAD\n") == nil)
    }

    @Test func trimsTheTrailingNewline() {
        #expect(GitBranch.clean("main\n") == "main")
        #expect(GitBranch.clean("  feature/x  \n") == "feature/x")
    }

    @Test func treatsEmptyOutputAsNoBranch() {
        #expect(GitBranch.clean("") == nil)
        #expect(GitBranch.clean("\n  \n") == nil)
    }
}
