import Foundation
import Testing

@testable import PiUI

struct LineBufferTests {
    private func text(_ lines: [Data]) -> [String] {
        lines.map { String(decoding: $0, as: UTF8.self) }
    }

    @Test func splitsOnLineFeed() {
        var buffer = LineBuffer()
        let lines = buffer.take(Data(#"{"a":1}"# .utf8) + Data("\n".utf8))
        #expect(text(lines) == [#"{"a":1}"#])
    }

    @Test func holdsPartialLineUntilItCompletes() {
        var buffer = LineBuffer()
        #expect(buffer.take(Data(#"{"a"#.utf8)).isEmpty)
        #expect(buffer.take(Data(#"":1}"#.utf8)).isEmpty)
        #expect(text(buffer.take(Data("\n".utf8))) == [#"{"a":1}"#])
    }

    @Test func stripsTrailingCarriageReturn() {
        var buffer = LineBuffer()
        let lines = buffer.take(Data("{}\r\n".utf8))
        #expect(text(lines) == ["{}"])
    }

    @Test func splitsSeveralLinesFromOneChunk() {
        var buffer = LineBuffer()
        let lines = buffer.take(Data("{\"a\":1}\n{\"b\":2}\n{\"c\":3}\n".utf8))
        #expect(text(lines) == [#"{"a":1}"#, #"{"b":2}"#, #"{"c":3}"#])
    }

    /// Node's readline splits on these too, which corrupts records. Ours must not.
    @Test func keepsUnicodeSeparatorsInsideTheRecord() {
        var buffer = LineBuffer()
        let payload = "{\"text\":\"a\u{2028}b\u{2029}c\"}"
        let lines = buffer.take(Data((payload + "\n").utf8))
        #expect(lines.count == 1)
        #expect(text(lines) == [payload])
    }

    @Test func skipsBlankLines() {
        var buffer = LineBuffer()
        let lines = buffer.take(Data("\n\n{\"a\":1}\n\n".utf8))
        #expect(text(lines) == [#"{"a":1}"#])
    }

    @Test func handlesMultiByteCharactersSplitAcrossChunks() {
        var buffer = LineBuffer()
        let payload = Data("{\"text\":\"é☃\"}\n".utf8)
        #expect(buffer.take(payload.prefix(9)).isEmpty)
        let lines = buffer.take(payload.suffix(from: 9))
        #expect(text(lines) == ["{\"text\":\"é☃\"}"])
    }
}
