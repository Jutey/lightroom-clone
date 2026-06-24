import SwiftUI

/// Side panel for the masks tool: lists existing masks (select/enable/delete) and, once a
/// mask is selected, exposes its local adjustment sliders via the same `EditSliderRow` +
/// `maskBinding` pattern every other panel uses. Geometry (position/size/rotation/strokes) is
/// only editable on the canvas via `MaskToolView` — this panel never touches geometry fields.
struct MasksPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Masks").font(.caption.bold())
                Spacer()
                Menu {
                    Button("Radial Mask") { addMask(.radial) }
                    Button("Linear Mask") { addMask(.linear) }
                    Button("Brush Mask") { addMask(.brush) }
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if app.editor.edit.localAdjustments.isEmpty {
                Text("No masks added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(app.editor.edit.localAdjustments) { mask in
                        maskRow(mask)
                    }
                }
            }

            if let mask = selectedMask {
                Divider()
                Text("\(mask.displayName) Adjustments")
                    .font(.caption.bold())
                adjustmentSliders(for: mask)
            }

            ResetPanelButton(kind: .masks)
        }
        .padding(10)
    }

    private var selectedMask: LocalAdjustmentMask? {
        guard let id = app.editor.selectedMaskID else { return nil }
        return app.editor.edit.localAdjustments.first(where: { $0.id == id })
    }

    private func maskRow(_ mask: LocalAdjustmentMask) -> some View {
        let isSelected = mask.id == app.editor.selectedMaskID
        return HStack(spacing: 6) {
            Image(systemName: icon(for: mask.kind))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(mask.displayName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: app.editor.maskBoolBinding(mask.id, \.isEnabled, actionName: "Toggle Mask"))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button(role: .destructive) {
                deleteMask(mask)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { selectAndEdit(mask) }
    }

    private func icon(for kind: LocalMaskKind) -> String {
        switch kind {
        case .radial: return "circle.dashed"
        case .linear: return "line.diagonal"
        case .brush: return "paintbrush.pointed"
        }
    }

    @ViewBuilder
    private func adjustmentSliders(for mask: LocalAdjustmentMask) -> some View {
        VStack(spacing: 10) {
            EditSliderRow(
                title: "Exposure", value: app.editor.maskBinding(mask.id, \.exposure),
                range: -5...5, defaultValue: 0, step: 0.05,
                format: { String(format: "%.2f", $0) }, actionName: "Mask Exposure"
            )
            EditSliderRow(title: "Contrast", value: app.editor.maskBinding(mask.id, \.contrast), actionName: "Mask Contrast")
            EditSliderRow(title: "Highlights", value: app.editor.maskBinding(mask.id, \.highlights), actionName: "Mask Highlights")
            EditSliderRow(title: "Shadows", value: app.editor.maskBinding(mask.id, \.shadows), actionName: "Mask Shadows")
            EditSliderRow(title: "Whites", value: app.editor.maskBinding(mask.id, \.whites), actionName: "Mask Whites")
            EditSliderRow(title: "Blacks", value: app.editor.maskBinding(mask.id, \.blacks), actionName: "Mask Blacks")

            Divider()

            EditSliderRow(title: "Temperature", value: app.editor.maskBinding(mask.id, \.temperature), actionName: "Mask Temperature")
            EditSliderRow(title: "Tint", value: app.editor.maskBinding(mask.id, \.tint), actionName: "Mask Tint")
            EditSliderRow(title: "Saturation", value: app.editor.maskBinding(mask.id, \.saturation), actionName: "Mask Saturation")

            Divider()

            EditSliderRow(title: "Clarity", value: app.editor.maskBinding(mask.id, \.clarity), actionName: "Mask Clarity")
            EditSliderRow(
                title: "Sharpness", value: app.editor.maskBinding(mask.id, \.sharpness),
                range: 0...100, defaultValue: 0, actionName: "Mask Sharpness"
            )
            EditSliderRow(
                title: "Noise Reduction", value: app.editor.maskBinding(mask.id, \.noiseReduction),
                range: 0...100, defaultValue: 0, actionName: "Mask Noise Reduction"
            )
        }
    }

    private func selectAndEdit(_ mask: LocalAdjustmentMask) {
        app.editor.selectedMaskID = mask.id
        app.library.viewMode = .loupe
        app.requestActiveTool(.masks)
    }

    private func addMask(_ kind: LocalMaskKind) {
        let id = app.editor.addMask(kind: kind)
        app.editor.selectedMaskID = id
        app.library.viewMode = .loupe
        app.requestActiveTool(.masks)
    }

    private func deleteMask(_ mask: LocalAdjustmentMask) {
        app.editor.deleteMask(id: mask.id)
        if app.editor.selectedMaskID == mask.id {
            app.editor.selectedMaskID = nil
        }
    }
}
