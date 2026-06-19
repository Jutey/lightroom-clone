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

final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.firstResponder === window.contentView {
                window.makeFirstResponder(self)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        nextResponder?.keyDown(with: event)
    }
}
