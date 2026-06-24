import SwiftUI

/// Right-hand inspector: hosts every edit panel as a collapsible, drag-to-reorder section.
/// Order and collapse state persist via `SettingsStore` (`panelOrder`/`collapsedPanelKinds`).
struct EditorPanelContainerView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if app.library.activePhoto != nil {
                List {
                    ForEach(SettingsStore.shared.orderedEditorPanels) { kind in
                        DisclosureGroup(isExpanded: collapsedBinding(for: kind)) {
                            panel(for: kind)
                        } label: {
                            Label(kind.title, systemImage: kind.systemImage)
                                .font(.subheadline)
                        }
                    }
                    .onMove { source, destination in
                        movePanels(from: source, to: destination)
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No Photo Selected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 280, idealWidth: 320)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(app.library.activePhoto?.displayName ?? "No Photo Selected")
                    .font(.headline)
                    .lineLimit(1)
                if let photo = app.library.activePhoto {
                    Text("\(photo.pixelWidth) × \(photo.pixelHeight) · \(Formatters.megapixels(width: photo.pixelWidth, height: photo.pixelHeight))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button("Copy Edits") { app.editor.copyEdits() }
                Button("Paste Edits") { app.editor.pasteEdits(includeCropAndPerspective: false) }
                    .disabled(!EditClipboard.shared.hasContent)
                Button("Paste Edits + Crop/Perspective") { app.editor.pasteEdits(includeCropAndPerspective: true) }
                    .disabled(!EditClipboard.shared.hasContent)
                Divider()
                Button("Reset All Edits", role: .destructive) { app.editor.resetAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(app.library.activePhoto == nil)
        }
        .padding(10)
    }

    @ViewBuilder
    private func panel(for kind: EditorPanelKind) -> some View {
        switch kind {
        case .light: LightPanelView()
        case .color: ColorPanelView()
        case .toneCurve: ToneCurvePanelView()
        case .hsl: HSLPanelView()
        case .colorGrading: ColorGradingPanelView()
        case .effects: EffectsPanelView()
        case .detail: DetailPanelView()
        case .lens: LensPanelView()
        case .lut: LUTPanelView()
        case .masks: MasksPanelView()
        case .crop: CropPanelView()
        case .presets: PresetsPanelView()
        case .history: HistoryPanelView()
        }
    }

    private func collapsedBinding(for kind: EditorPanelKind) -> Binding<Bool> {
        Binding(
            get: { !SettingsStore.shared.isPanelCollapsed(kind) },
            set: { isExpanded in SettingsStore.shared.setPanelCollapsed(kind, collapsed: !isExpanded) }
        )
    }

    private func movePanels(from source: IndexSet, to destination: Int) {
        var order = SettingsStore.shared.orderedEditorPanels
        order.move(fromOffsets: source, toOffset: destination)
        SettingsStore.shared.panelOrder = order.map(\.rawValue)
    }
}
