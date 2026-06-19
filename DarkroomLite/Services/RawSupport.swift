import Foundation
import CoreImage

/// Thin wrapper around `CIRAWFilter` so the rest of the app can treat RAW and
/// standard image formats uniformly. RAW decoding quality settings are kept
/// conservative (draft mode for thumbnails, full quality for editing/export) to
/// keep the app responsive on large libraries without blocking on full RAW decodes.
enum RawSupport {
    static func ciImage(contentsOf url: URL, draft: Bool) -> CIImage? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        filter.isDraftModeEnabled = draft
        filter.boostAmount = 1.0
        return filter.outputImage
    }
}
