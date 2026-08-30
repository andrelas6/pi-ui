import Foundation
import Testing

@testable import PiUI

@MainActor
struct SessionStoreTests {
    private func tempIndex() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "pi-ui-index-\(UUID().uuidString).json")
    }

    private func tempSessionFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "s-\(UUID().uuidString).jsonl")
        try Data("{}\n".utf8).write(to: url)
        return url
    }

    private func discard(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    @Test func remembersASession() {
        let store = SessionStore(file: tempIndex())
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: nil)
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].id == "a")
        #expect(store.sessions[0].folder.path == "/tmp/app")
    }

    @Test func doesNotDuplicateOnReopen() {
        let store = SessionStore(file: tempIndex())
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: nil)
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: nil)
        #expect(store.sessions.count == 1)
    }

    @Test func survivesARelaunch() throws {
        let index = tempIndex()
        let file = try tempSessionFile()

        let first = SessionStore(file: index)
        first.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: file)
        first.rename("a", to: "my work")

        let second = SessionStore(file: index)
        #expect(second.sessions.count == 1)
        #expect(second.sessions[0].name == "my work")
        #expect(second.sessions[0].file == file)
    }

    /// The acceptance criterion for S4.
    @Test func flagsASessionWhoseFileWentAway() throws {
        let index = tempIndex()
        let file = try tempSessionFile()

        let first = SessionStore(file: index)
        first.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: file)
        #expect(first.isMissing("a") == false)

        try discard(file)

        let afterRelaunch = SessionStore(file: index)
        #expect(afterRelaunch.isMissing("a") == true)
        #expect(afterRelaunch.sessions.count == 1)
    }

    /// pi writes the file lazily, so one that never had content is new, not lost.
    @Test func doesNotFlagASessionThatNeverWroteAnything() {
        let index = tempIndex()
        let neverWritten = FileManager.default.temporaryDirectory
            .appending(path: "nope-\(UUID().uuidString).jsonl")

        let first = SessionStore(file: index)
        first.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: neverWritten)

        let afterRelaunch = SessionStore(file: index)
        #expect(afterRelaunch.isMissing("a") == false)
    }

    @Test func clearsMissingWhenTheFileComesBack() throws {
        let index = tempIndex()
        let file = try tempSessionFile()

        let store = SessionStore(file: index)
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: file)
        try discard(file)
        store.reconcile()
        #expect(store.isMissing("a") == true)

        try Data("{}\n".utf8).write(to: file)
        store.reconcile()
        #expect(store.isMissing("a") == false)
    }

    @Test func titleFallsBackToTheFolderName() {
        let store = SessionStore(file: tempIndex())
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/my-app"), file: nil)
        #expect(store.sessions[0].title == "my-app")

        store.rename("a", to: "  ")
        #expect(store.sessions[0].title == "my-app")

        store.rename("a", to: "Real name")
        #expect(store.sessions[0].title == "Real name")
    }

    @Test func forgetsASession() {
        let store = SessionStore(file: tempIndex())
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: nil)
        store.forget("a")
        #expect(store.sessions.isEmpty)
    }

    @Test func tracksWhichSessionsAreRunning() {
        let store = SessionStore(file: tempIndex())
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/app"), file: nil)
        #expect(store.isRunning("a") == false)

        store.markRunning("a")
        #expect(store.isRunning("a") == true)

        store.markStopped("a")
        #expect(store.isRunning("a") == false)
    }
}
