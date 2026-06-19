import SwiftUI
import SwiftData

/// Lists built-in and user-saved presets. Applying a preset goes to the whole current
/// selection (via `AppController.applyPresetToSelection`) when more than one photo is
/// selected, otherwise just to the active photo in the live editor.
struct PresetsPanelView: View {
    @Environment(AppController.self) private var app
    @Query(sort: \Preset.sortOrder) private var presets: [Preset]

    @State private var isNamingPreset = false
    @State private var newPresetName: String = ""

    private var builtIns: [Preset] { presets.filter { $0.isBuiltIn } }
    private var userPresets: [Preset] { presets.filter { !$0.isBuiltIn } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Save Current as Preset…") {
                newPresetName = ""
                isNamingPreset = true
            }

            if !builtIns.isEmpty {
                Text("Built-In").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(builtIns) { preset in presetRow(preset, deletable: false) }
            }

            Text("User Presets").font(.caption.bold()).foregroundStyle(.secondary)
            if userPresets.isEmpty {
                Text("No saved presets yet").font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(userPresets) { preset in presetRow(preset, deletable: true) }
            }
        }
        .padding(10)
        .alert("Save Preset", isPresented: $isNamingPreset) {
            TextField("Name", text: $newPresetName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard !newPresetName.isEmpty, let modelContext = app.modelContext else { return }
                app.editor.saveAsPreset(name: newPresetName, modelContext: modelContext)
            }
        }
    }

    private func presetRow(_ preset: Preset, deletable: Bool) -> some View {
        HStack {
            Text(preset.name).font(.caption)
            Spacer()
            Button("Apply") { applyPreset(preset) }
                .buttonStyle(.plain)
                .font(.caption)
            if deletable {
                Button {
                    app.modelContext?.delete(preset)
                    try? app.modelContext?.save()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func applyPreset(_ preset: Preset) {
        let selected = app.library.selectedPhotos(in: app.library.displayedPhotos)
        if selected.count > 1 {
            app.applyPresetToSelection(preset, photos: selected)
        } else {
            app.editor.applyPreset(preset)
        }
    }
}
