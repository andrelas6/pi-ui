import SwiftUI

/// A SwiftUI view that transparently monitors keys using NSEvent locally
/// so it can intercept up/down/enter while the TextField has focus.
struct ArrowsMonitor: NSViewRepresentable {
    let up: () -> Void
    let down: () -> Void
    let enter: () -> Void

    enum ArrowKey: UInt16 {
        case enter = 36
        case down = 125
        case up = 126
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.up = up
        context.coordinator.down = down
        context.coordinator.enter = enter

        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            guard let coordinator = coordinator else { return event }
            guard let key = ArrowKey(rawValue: event.keyCode) else { return event }

            switch key {
            case .up:
                coordinator.up()
                return nil
            case .down:
                coordinator.down()
                return nil
            case .enter:
                coordinator.enter()
                return nil
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.up = up
        context.coordinator.down = down
        context.coordinator.enter = enter
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var up: () -> Void = {}
        var down: () -> Void = {}
        var enter: () -> Void = {}
        var monitor: Any?

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
