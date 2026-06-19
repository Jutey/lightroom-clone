import SwiftUI

/// Root of the macOS Settings scene (⌘,) — a tab per concern, each a thin form over
/// `SettingsStore.shared`. Hosted at a fixed 640×480 frame by `DarkroomLiteApp`.
struct SettingsRootView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            CropPerspectiveSettingsView()
                .tabItem { Label("Crop & Perspective", systemImage: "crop") }

            ConfirmationsSettingsView()
                .tabItem { Label("Confirmations", systemImage: "checkmark.shield") }

            ExportSettingsView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            KeyboardShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            LibrarySettingsView()
                .tabItem { Label("Library & Cache", systemImage: "photo.stack") }

            MetadataSettingsView()
                .tabItem { Label("Metadata", systemImage: "tag") }

            PerformanceSettingsView()
                .tabItem { Label("Performance", systemImage: "speedometer") }
        }
        .padding(20)
    }
}
