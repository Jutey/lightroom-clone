import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers

enum ExportImageFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case jpeg, png
    var id: String { rawValue }
    var label: String { self == .jpeg ? "JPEG" : "PNG" }
    var fileExtension: String { self == .jpeg ? "jpg" : "png" }
}

struct ExportOptions: Codable, Equatable, Sendable {
    var format: ExportImageFormat = .jpeg
    var jpegQuality: Double = 0.9 // 0...1
    var resizeLongEdge: Bool = false
    var longEdgePixels: Int = 2048
    var filenameSuffix: String = "_edited"
    var addSuffixToFilename: Bool = true
}

enum ExportSelectionScope: String, CaseIterable, Identifiable, Sendable {
    case selected, picked, allEdited, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .selected: return "Selected Photos"
        case .picked: return "All Picked Photos"
        case .allEdited: return "All Edited Photos"
        case .all: return "All Photos in Project"
        }
    }
}

/// A `Sendable` snapshot of everything `ExportService` needs from a `Photo`. Export runs on a
/// background task, and SwiftData model objects are only safe to touch from the actor that owns
/// their `ModelContext` (the main actor here) — so callers must snapshot each `Photo` into one of
/// these *before* hopping off the main actor, rather than passing live model objects across.
struct ExportPhotoTask: Sendable, Identifiable {
    var id: UUID
    var fileName: String
    var bookmarkData: Data?
    var relativePath: String
    var isRaw: Bool
    var edit: EditValues
    var crop: CropValues
    var perspective: PerspectiveValues

    init(photo: Photo) {
        self.id = photo.id
        self.fileName = photo.fileName
        self.bookmarkData = photo.bookmarkData
        self.relativePath = photo.relativePath
        self.isRaw = photo.isRaw
        self.edit = photo.editSettings?.values ?? .identity
        self.crop = photo.cropSettings?.values ?? .identity
        self.perspective = photo.perspectiveSettings?.values ?? .identity
    }
}

struct ExportResult {
    var succeeded: Int = 0
    var failed: [(fileName: String, error: Error)] = []
}

enum ExportError: LocalizedError {
    case sourceUnavailable
    case renderFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable: return "Could not access the original photo file."
        case .renderFailed: return "Could not render the edited image."
        case .writeFailed: return "Could not write the exported file."
        }
    }
}

enum ExportService {
    static func export(
        photos: [ExportPhotoTask],
        projectFolderBookmark: Data?,
        to destination: URL,
        options: ExportOptions,
        progress: @escaping (Int, Int) -> Void
    ) -> ExportResult {
        var result = ExportResult()
        let total = photos.count

        for (index, photo) in photos.enumerated() {
            do {
                try exportOne(photo: photo, projectFolderBookmark: projectFolderBookmark, to: destination, options: options)
                result.succeeded += 1
            } catch {
                result.failed.append((photo.fileName, error))
            }
            progress(index + 1, total)
        }
        return result
    }

    private static func exportOne(
        photo: ExportPhotoTask,
        projectFolderBookmark: Data?,
        to destination: URL,
        options: ExportOptions
    ) throws {
        let edit = photo.edit
        let crop = photo.crop
        let perspective = photo.perspective

        let ciImage: CIImage? = SecurityScopedFileAccess.withResolvedURL(
            bookmark: photo.bookmarkData,
            fallbackFolderBookmark: projectFolderBookmark,
            relativePath: photo.relativePath
        ) { url in
            ImageRenderer.loadSourceImage(url: url, isRaw: photo.isRaw, draft: false, rawAdjustments: edit.rawAdjustments)
        } ?? nil

        guard let source = ciImage else { throw ExportError.sourceUnavailable }

        var rendered = ImageRenderer.render(source: source, edit: edit, crop: crop, perspective: perspective)

        if options.resizeLongEdge {
            let extent = rendered.extent
            let longest = max(extent.width, extent.height)
            if longest > CGFloat(options.longEdgePixels) {
                let scale = CGFloat(options.longEdgePixels) / longest
                rendered = rendered.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }

        guard let cgImage = ImageRenderer.renderToCGImage(rendered) else { throw ExportError.renderFailed }

        let baseName = (photo.fileName as NSString).deletingPathExtension
        let suffix = options.addSuffixToFilename ? options.filenameSuffix : ""
        let fileName = "\(baseName)\(suffix).\(options.format.fileExtension)"
        let outputURL = uniqueURL(for: destination.appendingPathComponent(fileName))

        try write(cgImage: cgImage, to: outputURL, options: options)
    }

    private static func write(cgImage: CGImage, to url: URL, options: ExportOptions) throws {
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let data: Data?
        switch options.format {
        case .jpeg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: options.jpegQuality])
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        }
        guard let data else { throw ExportError.writeFailed }
        try data.write(to: url, options: .atomic)
    }

    private static func uniqueURL(for url: URL) -> URL {
        var candidate = url
        var counter = 1
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let folder = url.deletingLastPathComponent()
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
