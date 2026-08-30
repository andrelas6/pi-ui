import Foundation
import Observation

/// Menu commands live in the App scene, the work happens in the window. This carries
/// the intent across.
@MainActor
@Observable
final class Shortcuts {
    private(set) var newSessionCount = 0
    var jumpTo: Int?

    func askForNewSession() {
        newSessionCount += 1
    }
}
