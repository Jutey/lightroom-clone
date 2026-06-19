import Foundation
import SwiftData
import CoreGraphics

enum AspectRatioOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case freeform
    case original
    case square
    case ratio4x5
    case ratio5x4
    case ratio3x2
    case ratio2x3
    case ratio16x9
    case ratio9x16
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .freeform: return "Freeform"
        case .original: return "Original"
        case .square: return "1:1"
        case .ratio4x5: return "4:5"
        case .ratio5x4: return "5:4"
        case .ratio3x2: return "3:2"
        case .ratio2x3: return "2:3"
        case .ratio16x9: return "16:9"
        case .ratio9x16: return "9:16"
        case .custom: return "Custom"
        }
    }

    /// Width / height. `nil` means freeform or "use the original image ratio".
    var fixedRatio: CGFloat? {
        switch self {
        case .freeform, .original, .custom: return nil
        case .square: return 1
        case .ratio4x5: return 4.0 / 5.0
        case .ratio5x4: return 5.0 / 4.0
        case .ratio3x2: return 3.0 / 2.0
        case .ratio2x3: return 2.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        }
    }
}

enum CropGuideOverlay: String, Codable, CaseIterable, Identifiable {
    case none, thirds, goldenRatio, centerCross
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .thirds: return "Rule of Thirds"
        case .goldenRatio: return "Golden Ratio"
        case .centerCross: return "Center Cross"
        }
    }
}

/// Crop rectangle is stored normalized to the *unrotated* full image extent (0...1).
struct CropValues: Codable, Equatable, Sendable {
    var normalizedX: Double = 0
    var normalizedY: Double = 0
    var normalizedWidth: Double = 1
    var normalizedHeight: Double = 1
    var straightenAngle: Double = 0   // degrees, -45...45
    var rotationQuarterTurns: Int = 0 // 0,1,2,3 applied before crop rect
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false
    var aspectRatio: AspectRatioOption = .freeform
    var customAspectWidth: Double = 1
    var customAspectHeight: Double = 1

    static let identity = CropValues()

    var isIdentity: Bool { self == CropValues() }

    var normalizedRect: CGRect {
        CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }
}

/// Persistent, non-destructive crop/straighten/rotate/flip state for one photo.
@Model
final class CropSettings {
    var dataBlob: Data
    var isCropConfirmed: Bool = false
    var dateModified: Date = Date.now

    init(values: CropValues = .identity) {
        self.dataBlob = try! JSONEncoder().encode(values)
    }

    var values: CropValues {
        get { (try? JSONDecoder().decode(CropValues.self, from: dataBlob)) ?? .identity }
        set {
            dataBlob = try! JSONEncoder().encode(newValue)
            dateModified = .now
        }
    }
}
