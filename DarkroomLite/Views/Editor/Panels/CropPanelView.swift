import SwiftUI

/// Entry point for the crop/perspective tools, which are implemented as interactive
/// overlays on the loupe view (`CropToolView`/`PerspectiveToolView`), not as panel sliders.
/// `EditorViewModel.resetPanel` intentionally no-ops for `.crop`, so resets are handled
/// directly here against `app.editor.crop`/`perspective`.
struct CropPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolSection(
                title: "Crop & Straighten",
                isActive: app.library.activeTool == .crop,
                summary: cropSummary,
                onEnter: { app.library.viewMode = .loupe; app.requestActiveTool(.crop) },
                onReset: resetCrop
            )

            Divider()

            toolSection(
                title: "Perspective",
                isActive: app.library.activeTool == .perspective,
                summary: perspectiveSummary,
                onEnter: { app.library.viewMode = .loupe; app.requestActiveTool(.perspective) },
                onReset: resetPerspective
            )
        }
        .padding(10)
    }

    private var cropSummary: String {
        let crop = app.editor.crop
        return crop.isIdentity ? "No crop applied" : "\(crop.aspectRatio.label) · \(Int(crop.straightenAngle))°"
    }

    private var perspectiveSummary: String {
        app.editor.perspective.isIdentity ? "No correction applied" : "Adjusted"
    }

    private func resetCrop() {
        let old = (app.editor.edit, app.editor.crop, app.editor.perspective)
        app.editor.crop = .identity
        app.editor.registerUndo(actionName: "Reset Crop", oldEdit: old.0, oldCrop: old.1, oldPerspective: old.2)
        app.editor.scheduleRenderAndSave()
    }

    private func resetPerspective() {
        let old = (app.editor.edit, app.editor.crop, app.editor.perspective)
        app.editor.perspective = .identity
        app.editor.registerUndo(actionName: "Reset Perspective", oldEdit: old.0, oldCrop: old.1, oldPerspective: old.2)
        app.editor.scheduleRenderAndSave()
    }

    @ViewBuilder
    private func toolSection(
        title: String, isActive: Bool, summary: String, onEnter: @escaping () -> Void, onReset: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold())
            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Button(isActive ? "Editing…" : "Edit") { onEnter() }
                    .disabled(isActive)
                Spacer()
                Button("Reset", role: .destructive) { onReset() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
    }
}
