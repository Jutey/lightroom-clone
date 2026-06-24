import Foundation
import CoreImage

/// Thin wrapper around `CIRAWFilter` so the rest of the app can treat RAW and
/// standard image formats uniformly. RAW decoding quality settings are kept
/// conservative (draft mode for thumbnails, full quality for editing/export) to
/// keep the app responsive on large libraries without blocking on full RAW decodes.
enum RawSupport {
    static func ciImage(contentsOf url: URL, draft: Bool, adjustments: RawAdjustments = RawAdjustments()) -> CIImage? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        filter.isDraftModeEnabled = draft
        apply(adjustments, to: filter)
        return filter.outputImage
    }

    static func apply(_ adjustments: RawAdjustments, to filter: CIRAWFilter) {
        filter.exposure = Float(adjustments.exposure)
        filter.boostAmount = Float(adjustments.boostAmount / 100)
        if adjustments.useCustomWhiteBalance {
            filter.neutralTemperature = Float(adjustments.temperature)
            filter.neutralTint = Float(adjustments.tint)
        }
    }
}
