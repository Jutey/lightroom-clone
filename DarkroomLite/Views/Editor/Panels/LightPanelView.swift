import SwiftUI

struct LightPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            EditSliderRow(
                title: "Exposure", value: app.editor.binding(\.exposure),
                range: -5...5, defaultValue: 0, step: 0.05,
                format: { String(format: "%.2f", $0) }, actionName: "Exposure"
            )
            EditSliderRow(title: "Contrast", value: app.editor.binding(\.contrast), actionName: "Contrast")
            EditSliderRow(title: "Highlights", value: app.editor.binding(\.highlights), actionName: "Highlights")
            EditSliderRow(title: "Shadows", value: app.editor.binding(\.shadows), actionName: "Shadows")
            EditSliderRow(title: "Whites", value: app.editor.binding(\.whites), actionName: "Whites")
            EditSliderRow(title: "Blacks", value: app.editor.binding(\.blacks), actionName: "Blacks")

            ResetPanelButton(kind: .light)
        }
        .padding(10)
    }
}

/// Shared "Reset Panel" footer button used by every value-based edit panel — excludes Crop,
/// Presets, History, and LUT, which manage their own reset/management actions instead
/// (`EditorViewModel.resetPanel` intentionally no-ops for Crop/Presets/History).
struct ResetPanelButton: View {
    @Environment(AppController.self) private var app
    let kind: EditorPanelKind

    var body: some View {
        HStack {
            Spacer()
            Button("Reset Panel") { app.editor.resetPanel(kind) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
