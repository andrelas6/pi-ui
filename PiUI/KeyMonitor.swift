import AppKit

/// Menu key equivalents never reached us: the web view swallows them before the menu
/// is consulted. A local monitor sees the event first, so the shortcut always fires.
@MainActor
final class KeyMonitor {
    private var handle: Any?

    func start(
        newSession: @escaping () -> Void,
        jump: @escaping (Int) -> Void,
        interrupt: @escaping () -> Void = {},
        answer: @escaping (String) -> Bool = { _ in false },
        palette: @escaping () -> Void = {}
    ) {
        guard handle == nil else { return }

        handle = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let typed = event.charactersIgnoringModifiers else { return event }
            let held = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if held == .control, typed.lowercased() == "t" {
                // Run after this event finishes, so the panel is not opened mid-dispatch.
                DispatchQueue.main.async(execute: newSession)
                return nil
            }

            // Only swallowed when something is actually asking; otherwise these keys
            // belong to whatever has focus.
            if held == .command, typed.lowercased() == "k" {
                DispatchQueue.main.async(execute: palette)
                return nil
            }

            // Shift makes this its own combination: `held` is compared exactly, so
            // Cmd-Shift-Y never reaches the plain Cmd-Y branch below.
            if held == [.command, .shift],
               typed.lowercased() == "y",
               answer(ChatMessage.Request.always) {
                return nil
            }

            if held == .command, typed.lowercased() == "y", answer(ChatMessage.Request.allow) {
                return nil
            }

            if held == .command, typed.lowercased() == "r", answer(ChatMessage.Request.deny) {
                return nil
            }

            if held == .command, let number = Int(typed), (1...9).contains(number) {
                DispatchQueue.main.async { jump(number) }
                return nil
            }

            // Esc only means stop while something is running; otherwise it belongs to
            // whatever has focus.
            if held.isEmpty, event.keyCode == 53 {
                DispatchQueue.main.async(execute: interrupt)
                return event
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
