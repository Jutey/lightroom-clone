import Foundation
import SwiftData

/// A single imported photo. Always refers back to the original file on disk via a
/// security-scoped bookmark — Darkroom Lite never moves, renames, or overwrites the
/// source file. All edits live in `EditSettings` / `CropSettings` / `PerspectiveSettings`.
@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var relativePath: String
    var bookmarkData: Data?
    var fileExtension: String
    var isRaw: Bool

    var importDate: Date
    var captureDate: Date?
    var fileSize: Int
    var pixelWidth: Int
    var pixelHeight: Int

    // EXIF / metadata (best-effort, nil when unavailable)
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: String?
    var iso: Int?

    // Culling
    var rating: Int = 0
    var flagRaw: Int = PickFlag.none.rawValue
    var colorLabelRaw: Int = ColorLabelTag.none.rawValue
    var isTrashed: Bool = false

    var dateModified: Date
    var importOrder: Int = 0

    // Virtual copies: a virtual copy shares the same source file as its master but has
    // its own id, its own edits, and its own culling metadata.
    var isVirtualCopy: Bool = false
    var virtualCopyLabel: String?
    var masterPhotoID: UUID?

    var project: Project?

    @Relationship(deleteRule: .cascade)
    var editSettings: EditSettings?

    @Relationship(deleteRule: .cascade)
    var cropSettings: CropSettings?

    @Relationship(deleteRule: .cascade)
    var perspectiveSettings: PerspectiveSettings?

    @Relationship(deleteRule: .cascade, inverse: \EditSnapshot.photo)
    var snapshots: [EditSnapshot]? = []

    @Relationship
    var albums: [Album]? = []

    init(
        fileName: String,
        relativePath: String,
        fileExtension: String,
        bookmarkData: Data? = nil,
        fileSize: Int = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        captureDate: Date? = nil,
        importOrder: Int = 0
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.relativePath = relativePath
        self.fileExtension = fileExtension
        self.isRaw = SupportedFileType.isRaw(ext: fileExtension)
        self.bookmarkData = bookmarkData
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.captureDate = captureDate
        self.importDate = .now
        self.dateModified = .now
        self.importOrder = importOrder
    }

    var flag: PickFlag {
        get { PickFlag(rawValue: flagRaw) ?? .none }
        set { flagRaw = newValue.rawValue }
    }

    var colorLabel: ColorLabelTag {
        get { ColorLabelTag(rawValue: colorLabelRaw) ?? .none }
        set { colorLabelRaw = newValue.rawValue }
    }

    var hasEdits: Bool {
        let editIdentity = editSettings?.values.isIdentity ?? true
        let cropIdentity = cropSettings?.values.isIdentity ?? true
        let perspectiveIdentity = perspectiveSettings?.values.isIdentity ?? true
        return !(editIdentity && cropIdentity && perspectiveIdentity)
    }

    var displayName: String {
        if let label = virtualCopyLabel, isVirtualCopy {
            return "\(fileName) (\(label))"
        }
        return fileName
    }
}
