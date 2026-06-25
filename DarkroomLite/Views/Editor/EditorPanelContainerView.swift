import SwiftUI

/// Right-hand inspector: hosts every edit panel as a collapsible, drag-to-reorder section.
/// Order and collapse state persist via `SettingsStore` (`panelOrder`/`collapsedPanelKinds`).
struct EditorPanelContainerView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if app.library.activePhoto?.flag == .picked {
                HistogramView()
                List {
                    ForEach(SettingsStore.shared.orderedEditorPanels) { kind in
                        VStack(alignment: .leading, spacing: 0) {
                            DisclosureGroup(isExpanded: collapsedBinding(for: kind)) {
                                panel(for: kind)
                                    .padding(.top, 6)
                                    .padding(.bottom, 10)
                            } label: {
                                panelHeaderLabel(for: kind)
                            }
                            .disclosureGroupStyle(LightroomPanelDisclosureStyle())
                            Divider()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 0, trailing: 12))
                    }
                    .onMove { source, destination in
                        movePanels(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Text(app.library.activePhoto == nil ? "No Photo Selected" : "No Picked Photo")
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
        case .rawEdit: RawEditPanelView()
        case .lut: LUTPanelView()
        case .masks: MasksPanelView()
        case .spotRemoval: SpotRemovalPanelView()
        case .crop: CropPanelView()
        case .presets: PresetsPanelView()
        case .history: HistoryPanelView()
        }
    }

    private func panelHeaderLabel(for kind: EditorPanelKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(kind.title.uppercased())
                .font(.caption.bold())
                .kerning(0.4)
                .foregroundStyle(.primary)
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

/// Puts the collapse triangle on the leading edge of the header (Lightroom puts its panel
/// disclosure triangle to the left of the title, not trailing like the default macOS sidebar
/// style), and rotates it in place instead of swapping glyphs.
private struct LightroomPanelDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .frame(width: 10)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
