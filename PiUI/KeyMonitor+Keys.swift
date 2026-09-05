import SwiftUI

/// A SwiftUI view that transparently monitors keys using NSEvent locally
/// so it can intercept up/down/enter while the TextField has focus.
struct ArrowsMonitor: NSViewRepresentable {
    let up: () -> Void
    let down: () -> Void
    let enter: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.up = up
        context.coordinator.down = down
        context.coordinator.enter = enter

        DispatchQueue.main.async {
            context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
                guard let coordinator = coordinator else { return event }
                switch event.keyCode {
                case 126: // up
                    coordinator.up()
                    return nil
                case 125: // down
                    coordinator.down()
                    return nil
                case 36: // enter
                    coordinator.enter()
                    return nil
                default:
                    return event
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.up = up
        context.coordinator.down = down
        context.coordinator.enter = enter
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
