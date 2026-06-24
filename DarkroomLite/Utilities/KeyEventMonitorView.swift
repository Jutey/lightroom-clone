import SwiftUI
import AppKit

/// A zero-size NSView dropped into the SwiftUI hierarchy purely to intercept `keyDown`
/// events at the window level and match them against the user's customizable keyboard
/// shortcut map. SwiftUI's own `.keyboardShortcut`/`onKeyPress` modifiers can't express a
/// fully user-remappable scheme, so we go straight to AppKit for this one piece.
struct KeyEventMonitorView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

/// Watching for first-responder status doesn't work here: key events only reach whichever
/// view currently *is* the first responder, and that status moves to whatever the user last
/// clicked (a slider, a thumbnail, a list row — i.e. almost immediately after launch), so a
/// one-time claim in `viewDidMoveToWindow` would mean shortcuts stop firing for good the
/// moment focus moves anywhere else. A local event monitor sees every key event for this
/// window up front regardless of who holds focus, so shortcuts keep working continuously.
final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let self, let window, event.window === window else { return event }
            // Let active text editing (search fields, rename fields, etc.) receive keys normally.
            if window.firstResponder is NSTextView {
                return event
            }
            if self.onKeyDown?(event) == true {
                return nil
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        removeMonitor()
    }
}
