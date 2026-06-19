import SwiftUI

/// Autosave debounce and preview-quality tradeoffs.
struct PerformanceSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Section("Autosave") {
                VStack(alignment: .leading) {
                    Slider(value: $settings.autosaveDebounceMilliseconds, in: 100...2000, step: 50)
                    Text("Wait \(Int(settings.autosaveDebounceMilliseconds)) ms after the last edit before saving")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preview Quality") {
                Toggle("Use Fast Draft Mode for RAW Previews", isOn: $settings.rawDraftModeForPreview)

                VStack(alignment: .leading) {
                    Slider(value: $settings.maxPreviewDimension, in: 1000...4000, step: 100)
                    Text("Max preview dimension: \(Int(settings.maxPreviewDimension)) px")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }
}
