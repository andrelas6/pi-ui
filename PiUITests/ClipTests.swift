import Foundation
import Testing

@testable import PiUI

struct ClipTests {
    private func long(_ count: Int = 5_000) -> String {
        String(repeating: "x", count: count)
    }

    @Test func leavesAShortStringAlone() {
        #expect(Clip.value(.string("hello")) == .string("hello"))
    }

    /// The count is the point: it says how much was dropped, so a log reader can tell a
    /// large payload from a missing one.
    @Test func clipsALongStringAndSaysHowLongItWas() {
        let clipped = Clip.value(.string(long(5_000)))
        #expect(clipped == .string("‹clipped 5000 chars›"))
    }

    @Test func keepsAStringExactlyAtTheLimit() {
        let edge = String(repeating: "x", count: Clip.limit)
        #expect(Clip.value(.string(edge)) == .string(edge))
    }

    @Test func reachesInsideObjectsAndArrays() {
        let value = JSONValue.object([
            "keep": .string("short"),
            "deep": .array([.object(["big": .string(long())])]),
        ])
        let clipped = Clip.value(value)

        #expect(clipped["keep"] == .string("short"))
        #expect(clipped["deep"]?.array?.first?["big"]?.string?.hasPrefix("‹clipped") == true)
    }

    /// Structure has to survive, or the log stops answering the questions it exists for.
    @Test func keepsEverythingThatIsNotAString() {
        let value = JSONValue.object([
            "status": .string("completed"),
            "count": .number(3),
            "ok": .bool(true),
            "nothing": .null,
            "rawInput": .object([:]),
        ])
        #expect(Clip.value(value) == value)
    }

    @Test func changesNothingWhenNothingIsLong() {
        let value = JSONValue.array([.string("a"), .number(1), .object(["b": .string("c")])])
        #expect(Clip.value(value) == value)
    }

    @Test func countsCharactersNotBytes() {
        let emoji = String(repeating: "🙂", count: Clip.limit + 1)
        #expect(Clip.value(emoji.isEmpty ? .null : .string(emoji)) == .string("‹clipped \(Clip.limit + 1) chars›"))
    }
}
