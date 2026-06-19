import SwiftUI

/// Whether edits are mirrored to JSON sidecar files alongside the originals, and whether
/// sidecars are read back in when importing a folder.
struct MetadataSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Toggle("Write Sidecar Files for Edits", isOn: $settings.writeSidecarFiles)
            Toggle("Read Sidecar Files on Import", isOn: $settings.readSidecarFilesOnImport)
            Text("Sidecars are JSON files saved next to each original with the same name. The original photo file itself is never modified.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
