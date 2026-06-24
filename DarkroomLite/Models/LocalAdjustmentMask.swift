import Foundation
import CoreGraphics

/// The three Lightroom-style local adjustment mask shapes.
enum LocalMaskKind: String, Codable, CaseIterable, Sendable {
    case radial
    case linear
    case brush
}

/// A single point captured while dragging the brush mask tool, normalized 0...1 against
/// the rendered image extent in CoreImage's bottom-up coordinate space (same convention as
/// `CropValues.normalizedX/Y`).
struct BrushPoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
}

/// One continuous brush drag. `isErase` strokes subtract from the accumulated mask instead
/// of adding to it, so paint-then-erase and erase-then-paint both behave intuitively
/// regardless of stroke order (see `ImageRenderer.brushMaskImage`).
struct BrushStroke: Codable, Equatable, Sendable {
    var points: [BrushPoint] = []
    var isErase: Bool = false
}

/// A single local adjustment: a mask shape (radial/linear/brush) plus the tone/color deltas
/// applied only where that mask has influence. Geometry is normalized 0...1 against the
/// *final* rendered image extent (after crop/perspective/effects), since masks are the very
/// last step in `ImageRenderer.render` — unlike `CropValues`, there's no risk of the
/// normalization base shifting across edits.
struct LocalAdjustmentMask: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var kind: LocalMaskKind
    var isEnabled: Bool = true
    var isInverted: Bool = false

    // Radial geometry
    var centerX: Double = 0.5
    var centerY: Double = 0.5
    var radiusX: Double = 0.25
    var radiusY: Double = 0.25
    var rotation: Double = 0   // degrees
    var feather: Double = 50   // 0...100

    // Linear geometry. No separate feather: the distance between start/end *is* the
    // feather, mirroring how Lightroom's gradient tool behaves when dragged.
    var startX: Double = 0.3
    var startY: Double = 0.5
    var endX: Double = 0.7
    var endY: Double = 0.5

    // Brush geometry
    var brushSize: Double = 8       // diameter, percent of the image's shorter side
    var brushFeather: Double = 50   // 0...100
    var strokes: [BrushStroke] = []

    // Adjustment deltas, same scales as the equivalent global EditValues fields
    var exposure: Double = 0
    var contrast: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var temperature: Double = 0
    var tint: Double = 0
    var saturation: Double = 0
    var clarity: Double = 0
    var sharpness: Double = 0
    var noiseReduction: Double = 0

    init(kind: LocalMaskKind) {
        self.kind = kind
    }

    var hasAnyAdjustment: Bool {
        exposure != 0 || contrast != 0 || highlights != 0 || shadows != 0 || whites != 0 || blacks != 0
            || temperature != 0 || tint != 0 || saturation != 0 || clarity != 0 || sharpness != 0 || noiseReduction != 0
    }

    var displayName: String {
        switch kind {
        case .radial: return "Radial Mask"
        case .linear: return "Linear Mask"
        case .brush: return "Brush Mask"
        }
    }
}
