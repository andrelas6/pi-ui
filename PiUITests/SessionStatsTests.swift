import Foundation
import Testing

@testable import PiUI

struct SessionStatsTests {
    private func value(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func readsUsageAndCost() throws {
        let stats = try #require(SessionStats(try value(#"""
        {"data":{"cost":0.45,"tokens":{"total":105000},
                 "contextUsage":{"tokens":60000,"contextWindow":200000,"percent":30}}}
        """#)))

        #expect(stats.percent == 30)
        #expect(stats.contextWindow == 200_000)
        #expect(stats.contextText == "30%")
        #expect(stats.costText == "$0.45")
    }

    /// contextUsage is absent with no model, and null right after compaction.
    @Test func survivesMissingContextUsage() throws {
        let stats = try #require(SessionStats(try value(#"{"data":{"cost":0.1}}"#)))

        #expect(stats.percent == 0)
        #expect(stats.contextWindow == 0)
        #expect(stats.contextText == nil)
    }

    @Test func needsSomeData() throws {
        #expect(SessionStats(try value(#"{"success":true}"#)) == nil)
    }

    @Test func showsNothingForAFreeSession() throws {
        let stats = try #require(SessionStats(try value(#"{"data":{"cost":0}}"#)))
        #expect(stats.costText.isEmpty)
    }

    @Test func roundsTinyCostsUpToSomethingReadable() throws {
        let stats = try #require(SessionStats(try value(#"{"data":{"cost":0.0004}}"#)))
        #expect(stats.costText == "<$0.01")
    }

    @Test func warnsOnlyWhenContextIsTight() throws {
        func tight(_ percent: Int) throws -> Bool {
            try #require(SessionStats(try value(
                #"{"data":{"contextUsage":{"contextWindow":1000,"percent":\#(percent)}}}"#
            ))).isTight
        }

        #expect(try tight(30) == false)
        #expect(try tight(74) == false)
        #expect(try tight(75) == true)
        #expect(try tight(96) == true)
    }

    @Test func neverWarnsWithoutAContextWindow() throws {
        let stats = try #require(SessionStats(try value(#"{"data":{"cost":1}}"#)))
        #expect(stats.isTight == false)
    }
}
