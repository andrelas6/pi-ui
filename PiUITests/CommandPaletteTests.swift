import Foundation
import Testing

@testable import PiUI

struct PiCommandTests {
    private func value(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    /// The shape pi actually returns: the path is nested under sourceInfo, where the
    /// docs show it at the top level.
    @Test func readsTheShapePiReturns() throws {
        let command = try #require(PiCommand(try value(#"""
        {"name":"skill:tidy-imports","description":"Sort imports.","source":"skill",
         "sourceInfo":{"path":"/tmp/skills/tidy-imports/SKILL.md","source":"local"}}
        """#)))

        #expect(command.name == "skill:tidy-imports")
        #expect(command.detail == "Sort imports.")
        #expect(command.source == "skill")
        #expect(command.path == "/tmp/skills/tidy-imports/SKILL.md")
    }

    @Test func stillReadsThePathWhereTheDocsPutIt() throws {
        let command = try #require(PiCommand(try value(#"""
        {"name":"fix-tests","description":"Fix them.","source":"prompt","path":"/tmp/fix.md"}
        """#)))
        #expect(command.path == "/tmp/fix.md")
    }

    /// The prefix is noise in a list that already labels each row.
    @Test func dropsTheSkillPrefixFromTheTitle() throws {
        let skill = try #require(PiCommand(try value(#"{"name":"skill:brave","source":"skill"}"#)))
        #expect(skill.title == "brave")
        #expect(skill.name == "skill:brave")

        let plain = try #require(PiCommand(try value(#"{"name":"llama","source":"extension"}"#)))
        #expect(plain.title == "llama")
    }

    @Test func namesEachKindPlainly() throws {
        func kind(_ source: String) throws -> String {
            try #require(PiCommand(try value(#"{"name":"x","source":"\#(source)"}"#))).kind
        }
        #expect(try kind("skill") == "skill")
        #expect(try kind("prompt") == "template")
        #expect(try kind("extension") == "command")
    }

    @Test func needsAName() throws {
        #expect(PiCommand(try value(#"{"description":"orphan"}"#)) == nil)
        #expect(PiCommand(try value(#"{"name":"","source":"skill"}"#)) == nil)
    }

    @Test func sortsByTitleNotByPrefix() throws {
        let commands = PiCommand.all(from: try value(#"""
        {"data":{"commands":[
          {"name":"zebra","source":"extension"},
          {"name":"skill:apple","source":"skill"},
          {"name":"mango","source":"prompt"}
        ]}}
        """#))
        #expect(commands.map(\.title) == ["apple", "mango", "zebra"])
    }

    @Test func skipsEntriesItCannotRead() throws {
        let commands = PiCommand.all(from: try value(#"""
        {"data":{"commands":[{"name":"good","source":"skill"},{"broken":true}]}}
        """#))
        #expect(commands.map(\.name) == ["good"])
    }

    @Test func handlesNoCommandsAtAll() throws {
        #expect(PiCommand.all(from: try value(#"{"data":{"commands":[]}}"#)).isEmpty)
        #expect(PiCommand.all(from: try value(#"{}"#)).isEmpty)
    }

    @Test func searchesNameDescriptionAndKind() throws {
        let command = try #require(PiCommand(try value(#"""
        {"name":"skill:tidy-imports","description":"Sort and de-duplicate imports.","source":"skill"}
        """#)))

        #expect(command.matches(""))
        #expect(command.matches("tidy"))
        #expect(command.matches("duplicate"))
        #expect(command.matches("skill"))
        #expect(command.matches("tidy duplicate"))
        #expect(command.matches("TIDY"))
        #expect(command.matches("terraform") == false)
    }
}

@MainActor
struct PaletteRequestTests {
    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-palette-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    @Test func startsWithNoRequest() {
        #expect(newChat().paletteRequests == 0)
        #expect(newChat().commands.isEmpty)
    }

    /// Each press has to register, or a second ⌘K after dismissing would do nothing.
    @Test func eachPressIsItsOwnRequest() {
        let chat = newChat()
        chat.askForPalette()
        chat.askForPalette()
        #expect(chat.paletteRequests == 2)
    }
}
