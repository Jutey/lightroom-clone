import SwiftUI

/// Whether the Export sheet should remember the last-used options and destination.
struct ExportSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Toggle("Remember Last Export Settings", isOn: $settings.rememberLastExportSettings)
            Text("When enabled, the Export sheet reopens with the format, quality, resize, and destination you used last time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
