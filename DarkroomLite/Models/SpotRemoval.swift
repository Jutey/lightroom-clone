import Foundation
import CoreGraphics

/// A single spot-removal/healing edit: clones pixels sampled at `sourceX/Y` onto `targetX/Y`
/// with a feathered circular blend (see `ImageRenderer.applySpotRemovals`). Geometry is
/// normalized 0...1 against the rendered image extent after crop/perspective but before
/// tone/color/effects — same convention as `LocalAdjustmentMask`, minus the position-dependent
/// effects that would otherwise make a cloned patch look mismatched against its new location.
struct SpotRemoval: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var isEnabled: Bool = true

    // Destination (the blemish being covered)
    var targetX: Double = 0.5
    var targetY: Double = 0.5

    // Source (the clean area sampled from)
    var sourceX: Double = 0.6
    var sourceY: Double = 0.5

    var size: Double = 8       // diameter, percent of the image's shorter side
    var feather: Double = 50   // 0...100

    var displayName: String { "Spot Removal" }
}
