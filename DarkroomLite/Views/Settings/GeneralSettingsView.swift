import SwiftUI

/// Theme preferences only — color scheme and accent color.
struct GeneralSettingsView: View {
    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Picker("Appearance", selection: $settings.colorScheme) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.label).tag(scheme)
                }
            }

            Picker("Accent Color", selection: $settings.accentColor) {
                ForEach(AccentColorOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }

            Section {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
        .padding(20)
    }
}
