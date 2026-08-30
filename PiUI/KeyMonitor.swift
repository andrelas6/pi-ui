import AppKit

/// Menu key equivalents never reached us: the web view swallows them before the menu
/// is consulted. A local monitor sees the event first, so the shortcut always fires.
@MainActor
final class KeyMonitor {
    private var handle: Any?

    func start(newSession: @escaping () -> Void, jump: @escaping (Int) -> Void) {
        guard handle == nil else { return }

        handle = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let typed = event.charactersIgnoringModifiers else { return event }
            let held = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if held == .control, typed.lowercased() == "t" {
                // Run after this event finishes, so the panel is not opened mid-dispatch.
                DispatchQueue.main.async(execute: newSession)
                return nil
            }

            if held == .command, let number = Int(typed), (1...9).contains(number) {
                DispatchQueue.main.async { jump(number) }
                return nil
            }

            return event
        }
    }

    func stop() {
        guard let handle else { return }
        NSEvent.removeMonitor(handle)
        self.handle = nil
    }
}
