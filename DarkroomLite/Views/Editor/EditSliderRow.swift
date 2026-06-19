import SwiftUI

/// Wraps `SliderRow` so every edit-panel slider gets exactly one undo step per drag gesture,
/// no matter how many intermediate value changes the drag produces. The live value itself
/// comes from one of `EditorViewModel`'s side-effecting bindings (which already trigger a
/// debounced re-render/save on every change) — this view only adds undo grouping around the
/// gesture, via `SliderRow`'s existing `onEditingChanged` callback.
///
/// Note: `SliderRow`'s built-in double-click-to-reset bypasses `onEditingChanged`, so a
/// double-click reset won't register its own undo step. Accepted as a reasonable
/// simplification.
struct EditSliderRow: View {
    @Environment(AppController.self) private var app

    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = -100...100
    var defaultValue: Double = 0
    var step: Double = 1
    var format: (Double) -> String = { String(format: "%.0f", $0) }
    let actionName: String

    @State private var dragStartEdit: EditValues?
    @State private var dragStartCrop: CropValues?
    @State private var dragStartPerspective: PerspectiveValues?

    var body: some View {
        SliderRow(
            title: title,
            value: $value,
            range: range,
            defaultValue: defaultValue,
            step: step,
            format: format,
            onEditingChanged: { editing in
                if editing {
                    dragStartEdit = app.editor.edit
                    dragStartCrop = app.editor.crop
                    dragStartPerspective = app.editor.perspective
                } else if let oldEdit = dragStartEdit, let oldCrop = dragStartCrop, let oldPerspective = dragStartPerspective {
                    app.editor.registerUndo(actionName: actionName, oldEdit: oldEdit, oldCrop: oldCrop, oldPerspective: oldPerspective)
                    dragStartEdit = nil
                    dragStartCrop = nil
                    dragStartPerspective = nil
                }
            }
        )
    }
}
