import Foundation
import Observation
import SwiftData
import AppKit

/// Project (= imported folder) and album management: importing new folders, refreshing
/// existing ones for newly-added files, and organizing photos into albums/collections.
@MainActor
@Observable
final class ProjectsViewModel {
    private(set) var modelContext: ModelContext?
    var isImporting: Bool = false
    var lastImportError: String?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func importFolder(completion: @escaping (Project?) -> Void) {
        guard let context = modelContext else {
            completion(nil)
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a folder of photos to import as a new Darkroom Lite project."

        isImporting = true
        panel.begin { [weak self] response in
            guard let self else { return }
            defer { self.isImporting = false }
            guard response == .OK, let url = panel.urls.first else {
                completion(nil)
                return
            }
            let includeSubfolders = SettingsStore.shared.includeSubfoldersOnImport
            let existingCount = (try? context.fetch(FetchDescriptor<Project>()).count) ?? 0
            let project = ImportService.importFolder(
                url, includeSubfolders: includeSubfolders, into: context, existingSortOrderCount: existingCount
            )
            try? context.save()

            if SettingsStore.shared.readSidecarFilesOnImport {
                self.applySidecarsIfPresent(project: project)
            }
            completion(project)
        }
    }

    func refresh(_ project: Project) {
        guard let context = modelContext else { return }
        ImportService.refreshProject(project, into: context)
        try? context.save()
    }

    func renameProject(_ project: Project, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project.name = trimmed
        project.dateModified = .now
        try? modelContext?.save()
    }

    func deleteProject(_ project: Project) {
        modelContext?.delete(project)
        try? modelContext?.save()
    }

    func createAlbum(named name: String, in project: Project) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let context = modelContext else { return }
        let sortOrder = project.albums?.count ?? 0
        let album = Album(name: trimmed, project: project, sortOrder: sortOrder)
        context.insert(album)
        try? context.save()
    }

    func renameAlbum(_ album: Album, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        album.name = trimmed
        try? modelContext?.save()
    }

    func deleteAlbum(_ album: Album) {
        modelContext?.delete(album)
        try? modelContext?.save()
    }

    func add(_ photos: [Photo], to album: Album) {
        var current = album.photos ?? []
        let existingIDs = Set(current.map(\.id))
        for photo in photos where !existingIDs.contains(photo.id) {
            current.append(photo)
        }
        album.photos = current
        try? modelContext?.save()
    }

    func remove(_ photos: [Photo], from album: Album) {
        let removeIDs = Set(photos.map(\.id))
        album.photos = (album.photos ?? []).filter { !removeIDs.contains($0.id) }
        try? modelContext?.save()
    }

    private func applySidecarsIfPresent(project: Project) {
        guard let photos = project.photos, let context = modelContext else { return }
        for photo in photos {
            SecurityScopedFileAccess.withResolvedURL(
                bookmark: photo.bookmarkData,
                fallbackFolderBookmark: project.folderBookmark,
                relativePath: photo.relativePath
            ) { url in
                if let sidecar = SidecarService.read(fileURL: url) {
                    SidecarService.apply(sidecar, to: photo)
                }
            }
        }
        try? context.save()
    }
}
