import SwiftUI

struct ColorGradingPanelView: View {
    @Environment(AppController.self) private var app
    @State private var dragStartEdit: EditValues?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                wheelColumn(title: "Shadows", keyPath: \.shadows)
                wheelColumn(title: "Midtones", keyPath: \.midtones)
                wheelColumn(title: "Highlights", keyPath: \.highlights)
            }

            EditSliderRow(
                title: "Blending", value: app.editor.colorGradingBinding(\.blending),
                range: 0...100, defaultValue: 50, actionName: "Color Grading Blending"
            )
            EditSliderRow(title: "Balance", value: app.editor.colorGradingBinding(\.balance), actionName: "Color Grading Balance")

            ResetPanelButton(kind: .colorGrading)
        }
        .padding(10)
    }

    private func wheelColumn(title: String, keyPath: WritableKeyPath<ColorGradingValues, ColorGradingWheel>) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ColorWheelView(wheel: app.editor.colorGradingWheelBinding(keyPath), onEditingChanged: handleEditingChanged)
            EditSliderRow(
                title: "Luminance", value: app.editor.colorGradingLuminanceBinding(keyPath),
                step: 1, format: { String(format: "%.0f", $0) }, actionName: "\(title) Luminance"
            )
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        if editing {
            dragStartEdit = app.editor.edit
        } else if let oldEdit = dragStartEdit {
            app.editor.registerUndo(actionName: "Color Grading", oldEdit: oldEdit, oldCrop: app.editor.crop, oldPerspective: app.editor.perspective)
            dragStartEdit = nil
        }
    }
}
