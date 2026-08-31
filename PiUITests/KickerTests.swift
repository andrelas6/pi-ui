import Foundation
import Testing

@testable import PiUI

struct KickerTests {
    private func moment(_ hour: Int, _ minute: Int) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 8
        parts.day = 31
        parts.hour = hour
        parts.minute = minute
        return Calendar.current.date(from: parts) ?? .now
    }

    @Test func namesTheReaderAndTheTime() {
        #expect(Kickers.user(at: moment(14, 2)) == "YOU · 14:02")
    }

    /// A 24-hour clock regardless of the machine's locale, as the design draws it.
    @Test func padsAndUsesATwentyFourHourClock() {
        #expect(Kickers.time(moment(9, 5)) == "09:05")
        #expect(Kickers.time(moment(23, 59)) == "23:59")
        #expect(Kickers.time(moment(0, 0)) == "00:00")
    }

    @Test func namesTheModelThatSpoke() {
        #expect(Kickers.agent(model: "Opus 4.6") == "AGENT · OPUS 4.6")
        #expect(Kickers.agent(model: "glm-5.2") == "AGENT · GLM-5.2")
    }

    /// A session opened before a model is known must not read "AGENT · ".
    @Test func dropsTheSeparatorWithNoModel() {
        #expect(Kickers.agent(model: "") == "AGENT")
        #expect(Kickers.agent(model: "   ") == "AGENT")
    }

    /// pi stores message times as epoch milliseconds, not seconds.
    @Test func readsMillisecondsNotSeconds() {
        let stored = Kickers.moment(fromMilliseconds: 1_784_578_804_592)
        #expect(stored.timeIntervalSince1970 == 1_784_578_804.592)
    }

    @Test func fallsBackToNowWhenThereIsNoTime() {
        let missing = Kickers.moment(fromMilliseconds: nil)
        #expect(abs(missing.timeIntervalSinceNow) < 2)
        #expect(abs(Kickers.moment(fromMilliseconds: 0).timeIntervalSinceNow) < 2)
    }
}

struct DiffSummaryTests {
    private let sample = """
     1 alpha
    -2 beta
    +2 BETA
     3 gamma
    """

    @Test func countsWhatChanged() {
        let tally = DiffSummary.count(sample)
        #expect(tally.added == 1)
        #expect(tally.removed == 1)
    }

    @Test func readsAsTheDesignWritesIt() {
        #expect(DiffSummary.text(sample) == "+1 −1")
    }

    @Test func addsUpSeveralHunks() {
        let many = "+a\n+b\n+c\n-x\n context\n+d"
        #expect(DiffSummary.text(many) == "+4 −1")
    }

    /// Only a diff can say something honest in three words; nothing else tries.
    @Test func saysNothingWithoutADiff() {
        #expect(DiffSummary.text("") == "")
    }

    @Test func saysNothingWhenNothingChanged() {
        #expect(DiffSummary.text(" 1 alpha\n 2 beta") == "")
    }

    /// A context line beginning with a space must not be read as a removal.
    @Test func doesNotMistakeContextForAChange() {
        let tally = DiffSummary.count(" -not-a-removal\n 1 alpha")
        #expect(tally.added == 0)
        #expect(tally.removed == 0)
    }
}
