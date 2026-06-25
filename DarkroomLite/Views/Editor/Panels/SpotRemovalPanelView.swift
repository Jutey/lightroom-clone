import SwiftUI

/// Side panel for the spot removal tool: lists existing spots (select/enable/delete) and, once
/// a spot is selected, exposes its size/feather sliders via the same `EditSliderRow` +
/// `spotBinding` pattern every other panel uses. Position (target/source) is only editable on
/// the canvas via `SpotRemovalToolView` — this panel never touches geometry fields.
struct SpotRemovalPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Spot Removal").font(.caption.bold())
                Spacer()
                Button {
                    addSpot()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            if app.editor.edit.spotRemovals.isEmpty {
                Text("No spots added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(app.editor.edit.spotRemovals) { spot in
                        spotRow(spot)
                    }
                }
            }

            if let spot = selectedSpot {
                Divider()
                Text("\(spot.displayName) Adjustments")
                    .font(.caption.bold())
                adjustmentSliders(for: spot)
            }

            ResetPanelButton(kind: .spotRemoval)
        }
        .padding(10)
    }

    private var selectedSpot: SpotRemoval? {
        guard let id = app.editor.selectedSpotID else { return nil }
        return app.editor.edit.spotRemovals.first(where: { $0.id == id })
    }

    private func spotRow(_ spot: SpotRemoval) -> some View {
        let isSelected = spot.id == app.editor.selectedSpotID
        return HStack(spacing: 6) {
            Image(systemName: "bandage")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(spot.displayName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: app.editor.spotBoolBinding(spot.id, \.isEnabled, actionName: "Toggle Spot"))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button(role: .destructive) {
                deleteSpot(spot)
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
        .onTapGesture { selectAndEdit(spot) }
    }

    @ViewBuilder
    private func adjustmentSliders(for spot: SpotRemoval) -> some View {
        VStack(spacing: 10) {
            EditSliderRow(
                title: "Size", value: app.editor.spotBinding(spot.id, \.size),
                range: 1...50, defaultValue: 8, actionName: "Spot Size"
            )
            EditSliderRow(
                title: "Feather", value: app.editor.spotBinding(spot.id, \.feather),
                range: 0...100, defaultValue: 50, actionName: "Spot Feather"
            )
        }
    }

    private func selectAndEdit(_ spot: SpotRemoval) {
        app.editor.selectedSpotID = spot.id
        app.library.viewMode = .loupe
        app.requestActiveTool(.spotRemoval)
    }

    private func addSpot() {
        let id = app.editor.addSpot()
        app.editor.selectedSpotID = id
        app.library.viewMode = .loupe
        app.requestActiveTool(.spotRemoval)
    }

    private func deleteSpot(_ spot: SpotRemoval) {
        app.editor.deleteSpot(id: spot.id)
        if app.editor.selectedSpotID == spot.id {
            app.editor.selectedSpotID = nil
        }
    }
}
