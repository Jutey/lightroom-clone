import Foundation
import ImageIO
import CoreGraphics

struct ExtractedMetadata {
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
    var captureDate: Date?
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: String?
    var iso: Int?
}

/// Reads EXIF/TIFF metadata and pixel dimensions using ImageIO, which understands
/// JPEG/PNG/HEIC and most RAW formats without decoding the full-resolution image.
enum MetadataService {
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func extract(from url: URL) -> ExtractedMetadata {
        var result = ExtractedMetadata()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return result }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return result
        }

        result.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        result.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                result.captureDate = exifDateFormatter.date(from: dateString)
            }
            if let focal = exif[kCGImagePropertyExifFocalLength] as? Double {
                result.focalLength = focal
            }
            if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                result.aperture = fNumber
            }
            if let exposure = exif[kCGImagePropertyExifExposureTime] as? Double {
                result.shutterSpeed = formatShutterSpeed(exposure)
            }
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let iso = isoArray.first {
                result.iso = iso
            }
            if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                result.lensModel = lens
            }
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            result.cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
            result.cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
        }

        return result
    }

    private static func formatShutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        }
        let denominator = (1.0 / seconds).rounded()
        return "1/\(Int(denominator))"
    }
}
