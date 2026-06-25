import Foundation
import CoreGraphics

/// A control point on the parametric tone curve, normalized to 0...1 on both axes.
struct CurvePoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The eight Lightroom-style hue bands used by the color mixer / HSL panel.
enum HSLBandName: String, Codable, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, aqua, blue, purple, magenta
    var id: String { rawValue }

    /// Approximate center hue (0...360) for this band, used when building the color cube.
    var centerHue: Double {
        switch self {
        case .red: return 0
        case .orange: return 30
        case .yellow: return 60
        case .green: return 120
        case .aqua: return 180
        case .blue: return 220
        case .purple: return 270
        case .magenta: return 320
        }
    }
}

/// Per-band hue / saturation / luminance adjustment, each in -100...100.
struct HSLAdjustment: Codable, Equatable, Sendable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0

    var isIdentity: Bool { hue == 0 && saturation == 0 && luminance == 0 }
}

/// Three-way color grading wheel value: a hue/saturation point plus an independent luminance offset.
struct ColorGradingWheel: Codable, Equatable, Sendable {
    var hue: Double = 0         // 0...360
    var saturation: Double = 0  // 0...100 (radius on the wheel)
    var luminance: Double = 0   // -100...100

    var isIdentity: Bool { saturation == 0 && luminance == 0 }
}

struct ColorGradingValues: Codable, Equatable, Sendable {
    var shadows = ColorGradingWheel()
    var midtones = ColorGradingWheel()
    var highlights = ColorGradingWheel()
    var blending: Double = 50   // 0...100
    var balance: Double = 0     // -100...100, shifts split between shadows/highlights

    var isIdentity: Bool { shadows.isIdentity && midtones.isIdentity && highlights.isIdentity }
}

struct LensValues: Codable, Equatable, Sendable {
    var distortion: Double = 0           // -100...100
    var vignetteCorrection: Double = 0   // -100...100
    var removeChromaticAberration: Bool = false

    var isIdentity: Bool { distortion == 0 && vignetteCorrection == 0 && !removeChromaticAberration }
}

/// RAW-only adjustments applied to `CIRAWFilter` before demosaicing, rather than to the
/// already-decoded image the rest of the pipeline works with. Ignored for non-RAW photos.
struct RawAdjustments: Codable, Equatable, Sendable {
    var exposure: Double = 0              // -4...4 EV, applied in raw linear space pre-demosaic
    var boostAmount: Double = 100         // 0...200 (100 = camera-native default tone boost)
    var useCustomWhiteBalance: Bool = false
    var temperature: Double = 6500        // 2000...12000 K, only applied when useCustomWhiteBalance
    var tint: Double = 0                  // -150...150, only applied when useCustomWhiteBalance

    var isIdentity: Bool { exposure == 0 && boostAmount == 100 && !useCustomWhiteBalance }
}

/// A user-imported third-party `.cube` 3D LUT, applied as a creative-profile-style color
/// grade after every built-in tone/color adjustment. `intensity` cross-dissolves between
/// the pre-LUT and post-LUT image (100 = fully applied, 0 = no visible effect).
struct LUTReference: Codable, Equatable, Sendable {
    var bookmark: Data
    var displayName: String
    var intensity: Double = 100   // 0...100
}

/// A fully Codable snapshot of every adjustable edit parameter for a photo.
/// This is the value type used for the live editor, the clipboard (copy/paste edits),
/// presets, batch-apply, and history snapshots — `EditSettings` (the SwiftData model)
/// is just persistent storage that mirrors this struct.
struct EditValues: Codable, Equatable, Sendable {
    // Light
    var exposure: Double = 0          // -5...5 EV
    var contrast: Double = 0          // -100...100
    var highlights: Double = 0        // -100...100
    var shadows: Double = 0           // -100...100
    var whites: Double = 0            // -100...100
    var blacks: Double = 0            // -100...100

    // Color
    var temperature: Double = 0       // -100...100
    var tint: Double = 0              // -100...100
    var saturation: Double = 0        // -100...100
    var vibrance: Double = 0          // -100...100
    var isBlackAndWhite: Bool = false

    // Tone curve (RGB combined). Identity curve = empty/2-point straight line.
    var toneCurve: [CurvePoint] = EditValues.identityCurve

    // HSL / color mixer
    var hsl: [HSLBandName: HSLAdjustment] = [:]

    // Color grading
    var colorGrading = ColorGradingValues()

    // Effects
    var texture: Double = 0           // -100...100
    var clarity: Double = 0           // -100...100
    var dehaze: Double = 0            // -100...100
    var vignetteAmount: Double = 0    // -100...100
    var vignetteMidpoint: Double = 50 // 0...100
    var vignetteFeather: Double = 50  // 0...100
    var grainAmount: Double = 0       // 0...100
    var grainSize: Double = 25        // 0...100

    // Detail
    var sharpness: Double = 0         // 0...100
    var sharpenRadius: Double = 1     // 0.5...3
    var noiseReduction: Double = 0    // 0...100
    var colorNoiseReduction: Double = 0 // 0...100

    // Lens
    var lens = LensValues()

    // RAW-only decode adjustments (ignored for non-RAW photos)
    var rawAdjustments = RawAdjustments()

    // Imported LUT (creative profile)
    var lut: LUTReference? = nil

    // Local adjustment masks (radial/linear/brush), applied last, in array order
    var localAdjustments: [LocalAdjustmentMask] = []

    // Spot removal / healing brush, applied right after geometry and before tone/color
    var spotRemovals: [SpotRemoval] = []

    // CIFilter.toneCurve() takes exactly 5 points (point0...point4); the curve editor is
    // locked to these same 5 fixed x-positions, so identity is a straight line through them.
    static let identityCurve: [CurvePoint] = [
        CurvePoint(x: 0, y: 0),
        CurvePoint(x: 0.25, y: 0.25),
        CurvePoint(x: 0.5, y: 0.5),
        CurvePoint(x: 0.75, y: 0.75),
        CurvePoint(x: 1, y: 1)
    ]

    static let identity = EditValues()

    var isIdentity: Bool {
        self == EditValues()
    }

    var hasToneCurveEdit: Bool {
        toneCurve != EditValues.identityCurve
    }

    var hasHSLEdits: Bool {
        hsl.values.contains { !$0.isIdentity }
    }
}

// HSLBandName isn't naturally a Dictionary-friendly Codable key by default in all encoders,
// so we provide an explicit Codable conformance for [HSLBandName: HSLAdjustment] via a
// wrapper-free approach: HSLBandName is a String raw value enum, which Codable's
// JSONEncoder/PropertyListEncoder already support as dictionary keys natively.
