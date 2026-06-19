import SwiftUI
import AppKit

/// A zero-size NSView that becomes first responder while `isRecording` is true, captures
/// exactly one `keyDown`, converts it to a `KeyCombo`, and reports it via `onCapture`.
/// Escape cancels recording instead of being recorded, since it's the natural "never mind"
/// gesture and every other key (including modifier-only combos like ⌘Z) needs to remain
/// assignable.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (KeyCombo) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onKeyDown = { event in
            guard event.keyCode != 53, let combo = KeyCombo.from(event: event) else {
                onCancel()
                return
            }
            onCapture(combo)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        if isRecording, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class RecorderNSView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
