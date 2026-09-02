import Foundation

/// Where the ACP adapter lives. Named for the protocol rather than for Claude: the app
/// speaks ACP, and any adapter that does the same would work here.
enum AcpPath {
    static let variable = "ACP_PATH"

    enum Problem: Error, LocalizedError, Equatable {
        case notSet
        case missing(String)
        case notExecutable(String)

        var errorDescription: String? {
            switch self {
            case .notSet:
                "\(AcpPath.variable) is not set. Point it at your ACP adapter to start Claude sessions."
            case .missing(let path):
                "\(AcpPath.variable) points at \(path), which does not exist."
            case .notExecutable(let path):
                "\(AcpPath.variable) points at \(path), which is not executable."
            }
        }
    }

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        let raw = environment[variable]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { throw Problem.notSet }

        let path = (raw as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw Problem.missing(path)
        }
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw Problem.notExecutable(path)
        }
        return URL(fileURLWithPath: path)
    }
}
