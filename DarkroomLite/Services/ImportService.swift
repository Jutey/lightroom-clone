import Foundation
import SwiftData

/// Scans a user-selected folder and turns it into a `Project` full of `Photo` records.
/// Importing never copies or moves files — every photo keeps a security-scoped
/// bookmark back to its original location on disk.
enum ImportService {
    /// Creates a new project from `folderURL` (already approved via NSOpenPanel) and
    /// populates it with every supported image found inside.
    static func importFolder(
        _ folderURL: URL,
        includeSubfolders: Bool,
        into context: ModelContext,
        existingSortOrderCount: Int
    ) -> Project {
        let folderBookmark = SecurityScopedFileAccess.makeBookmark(for: folderURL)
        let project = Project(
            name: folderURL.lastPathComponent,
            folderPath: folderURL.path,
            folderBookmark: folderBookmark,
            sortOrder: existingSortOrderCount,
            includesSubfolders: includeSubfolders
        )
        context.insert(project)

        let files = enumerateSupportedFiles(in: folderURL, recursive: includeSubfolders)
        var order = 0
        for fileURL in files {
            let photo = makePhoto(from: fileURL, relativeTo: folderURL, importOrder: order)
            photo.project = project
            context.insert(photo)
            order += 1
        }
        return project
    }

    /// Re-scans a project's folder for new files not already in the library (e.g. the
    /// user added more photos to the same folder after the initial import).
    static func refreshProject(_ project: Project, into context: ModelContext) {
        guard let bookmark = project.folderBookmark,
              let folderURL = SecurityScopedFileAccess.resolveBookmark(bookmark) else { return }

        SecurityScopedFileAccess.withSecurityScopedAccess(to: folderURL) {
            let knownPaths = Set((project.photos ?? []).map(\.relativePath))
            let files = enumerateSupportedFiles(in: folderURL, recursive: project.includesSubfolders)
            var order = (project.photos?.map(\.importOrder).max() ?? -1) + 1
            for fileURL in files {
                let relativePath = relativePath(of: fileURL, relativeTo: folderURL)
                guard !knownPaths.contains(relativePath) else { continue }
                let photo = makePhoto(from: fileURL, relativeTo: folderURL, importOrder: order)
                photo.project = project
                context.insert(photo)
                order += 1
            }
            project.dateModified = .now
        }
    }

    private static func makePhoto(from fileURL: URL, relativeTo folderURL: URL, importOrder: Int) -> Photo {
        let ext = fileURL.pathExtension.lowercased()
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attributes?[.size] as? Int) ?? 0
        let metadata = MetadataService.extract(from: fileURL)
        let bookmark = SecurityScopedFileAccess.makeBookmark(for: fileURL)

        let photo = Photo(
            fileName: fileURL.lastPathComponent,
            relativePath: relativePath(of: fileURL, relativeTo: folderURL),
            fileExtension: ext,
            bookmarkData: bookmark,
            fileSize: fileSize,
            pixelWidth: metadata.pixelWidth,
            pixelHeight: metadata.pixelHeight,
            captureDate: metadata.captureDate,
            importOrder: importOrder
        )
        photo.cameraMake = metadata.cameraMake
        photo.cameraModel = metadata.cameraModel
        photo.lensModel = metadata.lensModel
        photo.focalLength = metadata.focalLength
        photo.aperture = metadata.aperture
        photo.shutterSpeed = metadata.shutterSpeed
        photo.iso = metadata.iso
        return photo
    }

    private static func relativePath(of fileURL: URL, relativeTo folderURL: URL) -> String {
        let folderComponents = folderURL.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        guard fileComponents.count > folderComponents.count else { return fileURL.lastPathComponent }
        return fileComponents[folderComponents.count...].joined(separator: "/")
    }

    private static func enumerateSupportedFiles(in folderURL: URL, recursive: Bool) -> [URL] {
        let fileManager = FileManager.default
        var results: [URL] = []

        let options: FileManager.DirectoryEnumerationOptions = recursive
            ? [.skipsHiddenFiles, .skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard SupportedFileType.isSupported(ext: ext) else { continue }
            results.append(fileURL)
        }

        return results.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
