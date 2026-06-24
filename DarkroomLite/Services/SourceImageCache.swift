import Foundation
import CoreImage

/// Small cache of decoded source `CIImage`s, keyed by photo ID, so cycling through
/// next/prev photos can reuse a background-decoded image instead of always decoding
/// on demand — the slow part for RAW files. Capacity is intentionally small since these
/// are full (draft-mode) source images, not thumbnails.
@MainActor
final class SourceImageCache {
    static let shared = SourceImageCache()

    private struct Entry {
        let image: CIImage
        let draft: Bool
    }

    private var entries: [UUID: Entry] = [:]
    private var order: [UUID] = []
    private var pendingPrefetches: Set<UUID> = []
    private let capacity = 6

    private init() {}

    func image(for photoID: UUID, draft: Bool) -> CIImage? {
        guard let entry = entries[photoID], entry.draft == draft else { return nil }
        return entry.image
    }

    func store(_ image: CIImage, for photoID: UUID, draft: Bool) {
        entries[photoID] = Entry(image: image, draft: draft)
        order.removeAll { $0 == photoID }
        order.append(photoID)
        while order.count > capacity {
            entries.removeValue(forKey: order.removeFirst())
        }
    }

    /// Decodes `photo`'s source image on a background task and caches it, unless a
    /// matching entry is already cached or already being fetched. Safe to call speculatively
    /// for photos that may never actually be opened.
    func prefetch(_ photo: Photo, projectFolderBookmark: Data?, draft: Bool) {
        let id = photo.id
        if let entry = entries[id], entry.draft == draft { return }
        guard !pendingPrefetches.contains(id) else { return }
        pendingPrefetches.insert(id)

        let bookmark = photo.bookmarkData
        let relativePath = photo.relativePath
        let isRaw = photo.isRaw

        Task.detached(priority: .utility) {
            let image = SecurityScopedFileAccess.withResolvedURL(
                bookmark: bookmark, fallbackFolderBookmark: projectFolderBookmark, relativePath: relativePath
            ) { url in
                ImageRenderer.loadSourceImage(url: url, isRaw: isRaw, draft: draft)
            } ?? nil
            await MainActor.run {
                if let image {
                    self.store(image, for: id, draft: draft)
                }
                self.pendingPrefetches.remove(id)
            }
        }
    }
}
