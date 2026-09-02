import Foundation
import Testing

@testable import PiUI

struct EventLogTests {
    private func folder() -> URL {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-log-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    private func records(in folder: URL) throws -> [JSONValue] {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
        return try files.flatMap { file in
            try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
        }
    }

    @Test func writesOneParseableObjectPerLine() async throws {
        let path = folder()
        let log = EventLog(folder: path)

        await log.wire("pi:demo", .into, .object(["type": .string("prompt")]))
        await log.wire("pi:demo", .from, .object(["type": .string("response")]))
        await log.app("opened", ["session": .string("s1")])

        let found = try records(in: path)
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0["at"]?.string?.isEmpty == false })
    }

    @Test func saysWhichWayAMessageWent() async throws {
        let path = folder()
        let log = EventLog(folder: path)
        await log.wire("claude:demo", .into, .object(["method": .string("session/prompt")]))
        await log.wire("claude:demo", .from, .object(["method": .string("session/update")]))

        let found = try records(in: path)
        #expect(found.compactMap { $0["dir"]?.string } == ["out", "in"])
        #expect(found.allSatisfy { $0["channel"]?.string == "claude:demo" })
        #expect(found.allSatisfy { $0["kind"]?.string == "wire" })
    }

    /// The reason the log exists is the payload shape, so it has to survive the trip.
    @Test func keepsTheShapeOfWhatItRecorded() async throws {
        let path = folder()
        let log = EventLog(folder: path)
        await log.wire("pi:demo", .from, .object([
            "type": .string("tool_execution_update"),
            "args": .object([:]),
            "status": .null,
        ]))

        let body = try #require(records(in: path).first?["body"])
        #expect(body["type"]?.string == "tool_execution_update")
        #expect(body["args"] == .object([:]))
        #expect(body["status"] == .null)
    }

    @Test func clipsAHugePayloadButKeepsTheRecord() async throws {
        let path = folder()
        let log = EventLog(folder: path)
        await log.wire("pi:demo", .from, .object(["content": .string(String(repeating: "x", count: 50_000))]))

        let found = try records(in: path)
        #expect(found.count == 1)
        #expect(found[0]["body"]?["content"]?.string?.hasPrefix("‹clipped 50000") == true)
    }

    @Test func recordsLifecycleWithItsDetail() async throws {
        let path = folder()
        let log = EventLog(folder: path)
        await log.life("pi:demo", "exit", ["status": .number(3)])

        let found = try records(in: path)
        #expect(found[0]["kind"]?.string == "life")
        #expect(found[0]["event"]?.string == "exit")
        #expect(found[0]["status"]?.number == 3)
    }

    /// A log that can break a session is worse than no log.
    @Test func staysQuietWhenItCannotWrite() async throws {
        let log = EventLog(folder: URL(fileURLWithPath: "/dev/null/not-a-folder"))
        await log.wire("pi:demo", .into, .object(["type": .string("prompt")]))
        await log.app("opened")
        // Reaching here without throwing or trapping is the whole assertion.
        #expect(Bool(true))
    }

    @Test func purgeEmptiesTheFolder() async throws {
        let path = folder()
        let log = EventLog(folder: path)
        await log.app("one")
        #expect(try records(in: path).count == 1)

        await log.purge()
        #expect(try records(in: path).isEmpty)
    }

    /// Oldest go first, and never the file being written to.
    @Test func prunesOldestUntilUnderTheCap() async throws {
        let path = folder()
        let manager = FileManager.default
        let bulk = Data(repeating: 0x61, count: 4_000)

        for day in 1...3 {
            let file = path.appending(path: "piui-2020-01-0\(day).jsonl")
            try bulk.write(to: file)
            try manager.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: Double(day) * 86_400)],
                ofItemAtPath: file.path
            )
        }
        let today = path.appending(path: EventLog.name(for: Date()))
        try bulk.write(to: today)

        await EventLog(folder: path).prune(cap: 9_000)

        let left = try manager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .sorted()
        #expect(left.contains(EventLog.name(for: Date())))
        #expect(left.contains("piui-2020-01-01.jsonl") == false)
        #expect(left.count == 2)
    }

    @Test func leavesTheFolderAloneWhenItIsSmallEnough() async throws {
        let path = folder()
        try Data(repeating: 0x61, count: 10).write(to: path.appending(path: "piui-2020-01-01.jsonl"))

        await EventLog(folder: path).prune(cap: 1_000)

        let left = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
        #expect(left.count == 1)
    }

    @Test func namesFilesByDay() {
        let moment = Date(timeIntervalSince1970: 1_756_800_000)
        #expect(EventLog.name(for: moment).hasPrefix("piui-"))
        #expect(EventLog.name(for: moment).hasSuffix(".jsonl"))
        #expect(EventLog.name(for: moment) == EventLog.name(for: moment.addingTimeInterval(60)))
    }
}
