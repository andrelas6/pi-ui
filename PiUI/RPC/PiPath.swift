import Foundation

enum PiPath {
    static let variable = "PI_PATH"

    enum Problem: Error, LocalizedError, Equatable {
        case notSet
        case missing(String)
        case notExecutable(String)

        var errorDescription: String? {
            switch self {
            case .notSet:
                "\(PiPath.variable) is not set. Point it at your pi executable to start sessions."
            case .missing(let path):
                "\(PiPath.variable) points at \(path), which does not exist."
            case .notExecutable(let path):
                "\(PiPath.variable) points at \(path), which is not executable."
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
