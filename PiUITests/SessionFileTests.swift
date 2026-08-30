import Foundation
import Testing

@testable import PiUI

struct SessionFileTests {
    private func jsonl(_ lines: [String]) -> Data {
        Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    @Test func readsIdAndFolderFromTheHeader() throws {
        let data = jsonl([
            #"{"type":"session","version":3,"id":"abc-123","timestamp":"2026-07-20T20:19:49.461Z","cwd":"/Users/me/work/app"}"#
        ])
        let file = try #require(SessionFile.parse(data))
        #expect(file.id == "abc-123")
        #expect(file.folder.path == "/Users/me/work/app")
        #expect(file.startedAt != nil)
    }

    /// The directory name replaces "/" with "-", so "first/app" and "first-app" collide.
    /// Reading cwd from the header is the only way to tell them apart.
    @Test func keepsFoldersThatContainDashes() throws {
        let data = jsonl([
            #"{"type":"session","version":3,"id":"x","timestamp":"2026-07-20T20:19:49.461Z","cwd":"/Users/me/haskell/first-app"}"#
        ])
        let file = try #require(SessionFile.parse(data))
        #expect(file.folder.path == "/Users/me/haskell/first-app")
        #expect(file.folder.lastPathComponent == "first-app")
    }

    @Test func takesTheLatestName() throws {
        let data = jsonl([
            #"{"type":"session","version":3,"id":"x","timestamp":"2026-07-20T20:19:49.461Z","cwd":"/tmp"}"#,
            #"{"type":"session_info","id":"a","parentId":null,"timestamp":"t","name":"first name"}"#,
            #"{"type":"message","id":"b","parentId":"a","timestamp":"t","message":{"role":"user","content":[]}}"#,
            #"{"type":"session_info","id":"c","parentId":"b","timestamp":"t","name":"second name"}"#,
        ])
        let file = try #require(SessionFile.parse(data))
        #expect(file.name == "second name")
    }

    @Test func hasNoNameWhenNeverSet() throws {
        let data = jsonl([
            #"{"type":"session","version":3,"id":"x","timestamp":"2026-07-20T20:19:49.461Z","cwd":"/tmp"}"#
        ])
        let file = try #require(SessionFile.parse(data))
        #expect(file.name == nil)
    }

    @Test func skipsUnparseableLines() throws {
        let data = jsonl([
            #"{"type":"session","version":3,"id":"x","timestamp":"2026-07-20T20:19:49.461Z","cwd":"/tmp"}"#,
            "not json at all",
            #"{"type":"session_info","id":"c","parentId":"b","timestamp":"t","name":"survived"}"#,
        ])
        let file = try #require(SessionFile.parse(data))
        #expect(file.name == "survived")
    }

    @Test func rejectsAFileThatDoesNotStartWithAHeader() {
        let data = jsonl([#"{"type":"message","id":"a","parentId":null,"message":{}}"#])
        #expect(SessionFile.parse(data) == nil)
    }

    @Test func rejectsEmptyData() {
        #expect(SessionFile.parse(Data()) == nil)
    }
}
