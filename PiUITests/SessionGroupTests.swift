import Foundation
import Testing

@testable import PiUI

@MainActor
struct SessionGroupTests {
    private func newStore() -> SessionStore {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-groups-\(UUID().uuidString).json")
        return SessionStore(file: index)
    }

    private func tempSessionFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "s-\(UUID().uuidString).jsonl")
        try Data("{}\n".utf8).write(to: url)
        return url
    }

    @Test func groupsSessionsByFolder() {
        let store = newStore()
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/one"), file: nil)
        store.remember(id: "b", folder: URL(fileURLWithPath: "/tmp/two"), file: nil)
        store.remember(id: "c", folder: URL(fileURLWithPath: "/tmp/one"), file: nil)

        let groups = store.groups
        #expect(groups.count == 2)

        let one = try? #require(groups.first { $0.title == "one" })
        #expect(one?.sessions.count == 2)
        #expect(groups.first { $0.title == "two" }?.sessions.count == 1)
    }

    /// Was most-recent-first until ⌘1–⌘9 arrived. Rows have to hold still for a
    /// number to keep meaning the same session, so the oldest folder leads.
    @Test func putsTheOldestFolderFirst() {
        let store = newStore()
        store.remember(id: "old", folder: URL(fileURLWithPath: "/tmp/old"), file: nil)
        store.remember(id: "new", folder: URL(fileURLWithPath: "/tmp/new"), file: nil)
        #expect(store.groups.first?.title == "old")
    }

    /// Two folders whose pi directory names collide must stay separate groups.
    @Test func keepsLookalikeFoldersApart() {
        let store = newStore()
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/first-app"), file: nil)
        store.remember(id: "b", folder: URL(fileURLWithPath: "/tmp/first/app"), file: nil)

        #expect(store.groups.count == 2)
        let paths = Set(store.groups.map(\.folder.path))
        #expect(paths == ["/tmp/first-app", "/tmp/first/app"])
    }

    @Test func hasNoGroupsWhenEmpty() {
        #expect(newStore().groups.isEmpty)
    }

    @Test func findsASessionById() {
        let store = newStore()
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/one"), file: nil)
        #expect(store.session("a")?.id == "a")
        #expect(store.session("nope") == nil)
    }

    @Test func trashDropsTheEntryAndTheFile() throws {
        let store = newStore()
        let file = try tempSessionFile()
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/one"), file: file)

        try store.trash("a")

        #expect(store.session("a") == nil)
        #expect(store.groups.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
    }

    @Test func trashWorksWhenTheFileIsAlreadyGone() throws {
        let store = newStore()
        let absent = FileManager.default.temporaryDirectory
            .appending(path: "gone-\(UUID().uuidString).jsonl")
        store.remember(id: "a", folder: URL(fileURLWithPath: "/tmp/one"), file: absent)

        try store.trash("a")
        #expect(store.session("a") == nil)
    }
}
