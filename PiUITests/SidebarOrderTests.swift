import Foundation
import Testing

@testable import PiUI

@MainActor
struct SidebarOrderTests {
    private func newStore() -> SessionStore {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-order-\(UUID().uuidString).json")
        return SessionStore(file: index)
    }

    /// ⌘1–⌘9 only work if rows never move, so using a session must not reorder anything.
    @Test func usingASessionDoesNotReorderTheSidebar() {
        let store = newStore()
        store.remember(id: "first", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        store.remember(id: "second", folder: URL(fileURLWithPath: "/tmp/b"), file: nil)
        store.remember(id: "third", folder: URL(fileURLWithPath: "/tmp/c"), file: nil)

        let before = store.ordered.map(\.id)
        #expect(before == ["first", "second", "third"])

        // Reopening the oldest one would have floated it to the top under the old order.
        store.remember(id: "first", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)

        #expect(store.ordered.map(\.id) == before)
    }

    @Test func newSessionsGoToTheBottom() {
        let store = newStore()
        store.remember(id: "first", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        store.remember(id: "second", folder: URL(fileURLWithPath: "/tmp/b"), file: nil)

        #expect(store.ordered.last?.id == "second")
    }

    @Test func numbersTheSidebarFromOne() {
        let store = newStore()
        store.remember(id: "first", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        store.remember(id: "second", folder: URL(fileURLWithPath: "/tmp/b"), file: nil)

        #expect(store.session(at: 1)?.id == "first")
        #expect(store.session(at: 2)?.id == "second")
    }

    @Test func ignoresNumbersWithNoSession() {
        let store = newStore()
        store.remember(id: "only", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)

        #expect(store.session(at: 2) == nil)
        #expect(store.session(at: 9) == nil)
        #expect(store.session(at: 0) == nil)
        #expect(store.session(at: -1) == nil)
    }

    @Test func groupsSessionsFromOneFolderTogether() {
        let store = newStore()
        store.remember(id: "a1", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        store.remember(id: "b1", folder: URL(fileURLWithPath: "/tmp/b"), file: nil)
        store.remember(id: "a2", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)

        // Folder a comes first because it was used first, and keeps both its sessions.
        #expect(store.ordered.map(\.id) == ["a1", "a2", "b1"])
    }

    @Test func ordersNothingWhenEmpty() {
        #expect(newStore().ordered.isEmpty)
        #expect(newStore().session(at: 1) == nil)
    }

    @Test func keepsOrderAcrossARelaunch() {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-order-\(UUID().uuidString).json")

        let first = SessionStore(file: index)
        first.remember(id: "one", folder: URL(fileURLWithPath: "/tmp/a"), file: nil)
        first.remember(id: "two", folder: URL(fileURLWithPath: "/tmp/b"), file: nil)
        let before = first.ordered.map(\.id)

        let second = SessionStore(file: index)
        #expect(second.ordered.map(\.id) == before)
    }
}
