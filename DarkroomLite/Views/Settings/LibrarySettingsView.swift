import SwiftUI

/// Import defaults and thumbnail cache management.
struct LibrarySettingsView: View {
    @State private var cacheSizeText = "Calculating…"

    var body: some View {
        @Bindable var settings = SettingsStore.shared

        Form {
            Toggle("Include Subfolders When Importing", isOn: $settings.includeSubfoldersOnImport)

            Section("Thumbnails") {
                VStack(alignment: .leading) {
                    Slider(value: $settings.thumbnailMaxPixelSize, in: 120...640, step: 20)
                    Text("Thumbnail size: \(Int(settings.thumbnailMaxPixelSize)) px")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Toggle("Generate Thumbnails in the Background", isOn: $settings.backgroundThumbnailGeneration)

                VStack(alignment: .leading) {
                    Slider(value: $settings.maxConcurrentThumbnailTasks, in: 1...8, step: 1)
                    Text("Concurrent thumbnail tasks: \(Int(settings.maxConcurrentThumbnailTasks))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Cache on disk: \(cacheSizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Thumbnail Cache") {
                        Task {
                            await ThumbnailService.shared.clearAllCaches()
                            await refreshCacheSize()
                        }
                    }
                }
            }
        }
        .padding(20)
        .task { await refreshCacheSize() }
    }

    private func refreshCacheSize() async {
        let bytes = await ThumbnailService.shared.cacheSizeOnDiskBytes()
        cacheSizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
