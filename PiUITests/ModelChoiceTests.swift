import Foundation
import Testing

@testable import PiUI

struct ModelChoiceTests {
    private func value(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func readsAModel() throws {
        let model = try #require(ModelChoice(try value(#"""
        {"id":"claude-opus-4.7","provider":"anthropic","name":"Claude Opus 4.7",
         "contextWindow":1000000,"cost":{"input":30,"output":150}}
        """#)))

        #expect(model.id == "anthropic/claude-opus-4.7")
        #expect(model.name == "Claude Opus 4.7")
        #expect(model.contextWindow == 1_000_000)
        #expect(model.costPerMillionIn == 30)
    }

    @Test func needsAProviderAndAnId() throws {
        #expect(ModelChoice(try value(#"{"provider":"anthropic"}"#)) == nil)
        #expect(ModelChoice(try value(#"{"id":"x"}"#)) == nil)
    }

    @Test func fallsBackToTheIdForAName() throws {
        let model = try #require(ModelChoice(try value(#"{"id":"glm-5.2","provider":"scaleway"}"#)))
        #expect(model.name == "glm-5.2")
        #expect(model.contextWindow == 0)
    }

    @Test func readsAWholeList() throws {
        let models = ModelChoice.all(from: try value(#"""
        {"data":{"models":[
          {"id":"a","provider":"p1"},
          {"broken":true},
          {"id":"b","provider":"p2"}
        ]}}
        """#))

        #expect(models.map(\.id) == ["p1/a", "p2/b"])
    }

    @Test func handlesAnEmptyList() throws {
        #expect(ModelChoice.all(from: try value(#"{"data":{"models":[]}}"#)).isEmpty)
        #expect(ModelChoice.all(from: try value(#"{}"#)).isEmpty)
    }

    /// 348 models means the search has to be forgiving about word order.
    @Test func searchesAcrossNameAndPath() throws {
        let model = try #require(ModelChoice(try value(#"""
        {"id":"claude-sonnet-4.5","provider":"anthropic","name":"Claude Sonnet 4.5"}
        """#)))

        #expect(model.matches(""))
        #expect(model.matches("sonnet"))
        #expect(model.matches("anthropic"))
        #expect(model.matches("claude sonnet"))
        #expect(model.matches("sonnet anthropic"))
        #expect(model.matches("SONNET"))
        #expect(model.matches("opus") == false)
    }
}
