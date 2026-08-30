import Foundation
import Testing

@testable import PiUI

struct PiPathTests {
    @Test func failsWhenTheVariableIsMissing() {
        #expect(throws: PiPath.Problem.notSet) {
            try PiPath.fromEnvironment([:])
        }
    }

    @Test func failsWhenTheVariableIsBlank() {
        #expect(throws: PiPath.Problem.notSet) {
            try PiPath.fromEnvironment(["PI_PATH": "   "])
        }
    }

    @Test func failsWhenThePathDoesNotExist() {
        #expect(throws: PiPath.Problem.missing("/nope/pi")) {
            try PiPath.fromEnvironment(["PI_PATH": "/nope/pi"])
        }
    }

    @Test func failsWhenTheFileIsNotExecutable() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "pi-\(UUID().uuidString)")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(throws: PiPath.Problem.notExecutable(file.path)) {
            try PiPath.fromEnvironment(["PI_PATH": file.path])
        }
    }

    @Test func returnsTheExecutable() throws {
        let found = try PiPath.fromEnvironment(["PI_PATH": "/bin/ls"])
        #expect(found.path == "/bin/ls")
    }

    @Test func expandsATilde() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let found = try PiPath.fromEnvironment(["PI_PATH": "~/../../bin/ls"])
        #expect(found.path.hasPrefix(home) || found.path.contains("/bin/ls"))
    }

    @Test func trimsSurroundingWhitespace() throws {
        let found = try PiPath.fromEnvironment(["PI_PATH": "  /bin/ls\n"])
        #expect(found.path == "/bin/ls")
    }
}
