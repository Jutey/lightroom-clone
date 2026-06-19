import Foundation
import ImageIO
import CoreGraphics
import CoreImage
import AppKit

/// Generates, caches, and serves thumbnails so the library grid and filmstrip can
/// stay smooth on libraries of thousands of photos. Thumbnails are cached on disk
/// (keyed by photo id) and mirrored in an in-memory `NSCache` for instant re-display.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private let memoryCache = NSCache<NSString, NSImage>()

    init() {
        memoryCache.countLimit = 800
    }

    /// Returns a cached thumbnail immediately if available, otherwise generates one,
    /// caches it to disk + memory, and returns it.
    func thumbnail(
        for photo: Photo,
        maxPixelSize: CGFloat,
        projectFolderBookmark: Data?
    ) async -> NSImage? {
        let cacheKey = "\(photo.id.uuidString)-\(Int(maxPixelSize))" as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        let diskURL = diskCacheURL(for: photo.id, maxPixelSize: maxPixelSize)
        if FileManager.default.fileExists(atPath: diskURL.path),
           let data = try? Data(contentsOf: diskURL),
           let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey)
            return image
        }

        guard let generated = generateThumbnail(
            for: photo,
            maxPixelSize: maxPixelSize,
            projectFolderBookmark: projectFolderBookmark
        ) else { return nil }

        memoryCache.setObject(generated.image, forKey: cacheKey)
        try? generated.jpegData?.write(to: diskURL)
        return generated.image
    }

    func invalidate(photoID: UUID) {
        for size in [160, 256, 512, 1024] {
            let key = "\(photoID.uuidString)-\(size)" as NSString
            memoryCache.removeObject(forKey: key)
            try? FileManager.default.removeItem(at: diskCacheURL(for: photoID, maxPixelSize: CGFloat(size)))
        }
    }

    func clearAllCaches() {
        memoryCache.removeAllObjects()
        let dir = PersistenceController.thumbnailCacheDirectory
        if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func cacheSizeOnDiskBytes() -> Int64 {
        let dir = PersistenceController.thumbnailCacheDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    private func diskCacheURL(for photoID: UUID, maxPixelSize: CGFloat) -> URL {
        PersistenceController.thumbnailCacheDirectory
            .appendingPathComponent("\(photoID.uuidString)-\(Int(maxPixelSize)).jpg")
    }

    private struct GeneratedThumbnail {
        let image: NSImage
        let jpegData: Data?
    }

    private nonisolated func generateThumbnail(
        for photo: Photo,
        maxPixelSize: CGFloat,
        projectFolderBookmark: Data?
    ) -> GeneratedThumbnail? {
        SecurityScopedFileAccess.withResolvedURL(
            bookmark: photo.bookmarkData,
            fallbackFolderBookmark: projectFolderBookmark,
            relativePath: photo.relativePath
        ) { url -> GeneratedThumbnail? in
            guard let cgImage = makeCGImageThumbnail(url: url, maxPixelSize: maxPixelSize, isRaw: photo.isRaw) else {
                return nil
            }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
            return GeneratedThumbnail(image: nsImage, jpegData: jpegData)
        } ?? nil
    }

    private nonisolated func makeCGImageThumbnail(url: URL, maxPixelSize: CGFloat, isRaw: Bool) -> CGImage? {
        if isRaw {
            guard let ciImage = RawSupport.ciImage(contentsOf: url, draft: true) else { return nil }
            let context = CIContext()
            let scale = maxPixelSize / max(ciImage.extent.width, ciImage.extent.height)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            return context.createCGImage(scaled, from: scaled.extent)
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
