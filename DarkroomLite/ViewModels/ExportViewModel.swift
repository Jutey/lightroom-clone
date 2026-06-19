import Foundation
import Observation
import AppKit

/// Drives the export sheet: scope/options selection, destination-folder picking, and
/// running `ExportService` off the main actor. `Photo` objects are snapshotted into
/// `ExportPhotoTask` values (see `ExportService.swift`) before the export task starts,
/// since SwiftData models must stay on the main actor that owns their `ModelContext`.
@MainActor
@Observable
final class ExportViewModel {
    var isPresented: Bool = false
    var scope: ExportSelectionScope = .selected
    var options: ExportOptions = ExportOptions()

    var isExporting: Bool = false
    var progressCurrent: Int = 0
    var progressTotal: Int = 0
    var lastResult: ExportResult?
    var lastDestination: URL?

    init() {
        if SettingsStore.shared.rememberLastExportSettings,
           let data = SettingsStore.shared.lastExportOptionsData,
           let decoded = try? JSONDecoder().decode(ExportOptions.self, from: data) {
            options = decoded
        }
    }

    func photosToExport(allPhotos: [Photo], selected: [Photo]) -> [Photo] {
        switch scope {
        case .selected: return selected.isEmpty ? allPhotos : selected
        case .picked: return allPhotos.filter { $0.flag == .picked }
        case .allEdited: return allPhotos.filter { $0.hasEdits }
        case .all: return allPhotos
        }
    }

    func chooseDestinationAndExport(photos: [Photo], projectFolderBookmark: Data?) {
        guard !photos.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a destination folder for the exported photos."
        if let lastBookmark = SettingsStore.shared.lastExportDestinationBookmark,
           let url = SecurityScopedFileAccess.resolveBookmark(lastBookmark) {
            panel.directoryURL = url
        }

        panel.begin { [weak self] response in
            guard let self, response == .OK, let destination = panel.urls.first else { return }

            if SettingsStore.shared.rememberLastExportSettings {
                SettingsStore.shared.lastExportDestinationBookmark = SecurityScopedFileAccess.makeBookmark(for: destination)
                SettingsStore.shared.lastExportOptionsData = try? JSONEncoder().encode(self.options)
            }

            self.runExport(photos: photos, projectFolderBookmark: projectFolderBookmark, destination: destination)
        }
    }

    private func runExport(photos: [Photo], projectFolderBookmark: Data?, destination: URL) {
        let tasks = photos.map(ExportPhotoTask.init)
        let options = self.options

        isExporting = true
        progressCurrent = 0
        progressTotal = tasks.count
        lastDestination = destination
        lastResult = nil

        Task {
            let result = await Task.detached(priority: .userInitiated) { [weak self] in
                ExportService.export(
                    photos: tasks,
                    projectFolderBookmark: projectFolderBookmark,
                    to: destination,
                    options: options
                ) { current, total in
                    Task { @MainActor in
                        self?.progressCurrent = current
                        self?.progressTotal = total
                    }
                }
            }.value
            self.isExporting = false
            self.lastResult = result
        }
    }
}
