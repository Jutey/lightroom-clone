import Foundation

/// Optional JSON sidecar files written next to the original photo (e.g. `IMG_001.jpg` ->
/// `IMG_001.darkroomlite.json`). The SwiftData store is always the source of truth; sidecars
/// are a portability/backup convenience that can be toggled in Settings > Metadata.
struct PhotoSidecar: Codable {
    var rating: Int
    var flag: Int
    var colorLabel: Int
    var edit: EditValues
    var crop: CropValues
    var perspective: PerspectiveValues
    var dateModified: Date
}

enum SidecarService {
    static func sidecarURL(for fileURL: URL) -> URL {
        let base = fileURL.deletingPathExtension().lastPathComponent
        return fileURL.deletingLastPathComponent().appendingPathComponent("\(base).darkroomlite.json")
    }

    static func write(for photo: Photo, fileURL: URL) {
        let sidecar = PhotoSidecar(
            rating: photo.rating,
            flag: photo.flagRaw,
            colorLabel: photo.colorLabelRaw,
            edit: photo.editSettings?.values ?? .identity,
            crop: photo.cropSettings?.values ?? .identity,
            perspective: photo.perspectiveSettings?.values ?? .identity,
            dateModified: .now
        )
        guard let data = try? JSONEncoder().encode(sidecar) else { return }
        try? data.write(to: sidecarURL(for: fileURL), options: .atomic)
    }

    static func read(fileURL: URL) -> PhotoSidecar? {
        let url = sidecarURL(for: fileURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PhotoSidecar.self, from: data)
    }

    static func apply(_ sidecar: PhotoSidecar, to photo: Photo) {
        photo.rating = sidecar.rating
        photo.flagRaw = sidecar.flag
        photo.colorLabelRaw = sidecar.colorLabel
        let edit = EditSettings(values: sidecar.edit)
        let crop = CropSettings(values: sidecar.crop)
        let perspective = PerspectiveSettings(values: sidecar.perspective)
        photo.editSettings = edit
        photo.cropSettings = crop
        photo.perspectiveSettings = perspective
    }
}
