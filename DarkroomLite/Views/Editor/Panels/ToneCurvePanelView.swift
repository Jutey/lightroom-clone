import SwiftUI

struct ToneCurvePanelView: View {
    @Environment(AppController.self) private var app
    @State private var dragStartEdit: EditValues?

    var body: some View {
        VStack(spacing: 10) {
            CurveEditorView(points: app.editor.toneCurveBinding(), onEditingChanged: handleEditingChanged)
                .frame(maxWidth: .infinity)

            ResetPanelButton(kind: .toneCurve)
        }
        .padding(10)
    }

    private func handleEditingChanged(_ editing: Bool) {
        if editing {
            dragStartEdit = app.editor.edit
        } else if let oldEdit = dragStartEdit {
            app.editor.registerUndo(actionName: "Tone Curve", oldEdit: oldEdit, oldCrop: app.editor.crop, oldPerspective: app.editor.perspective)
            dragStartEdit = nil
        }
    }
}
