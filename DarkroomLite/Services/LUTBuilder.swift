import Foundation
import CoreImage

/// Builds a 3D color lookup table (a `CIColorCube`) that encodes every per-hue and
/// per-luminance color adjustment: the 8-band HSL color mixer, 3-way color grading
/// wheels, saturation, vibrance, and the black & white toggle. Folding all of these
/// into one cube keeps the render pipeline fast (one filter instead of several) and
/// only relies on the very stable, long-standing `CIColorCube` Core Image filter.
///
/// Exposure/contrast/highlights/shadows/whites/blacks/temperature/tint/sharpen/noise/
/// vignette/grain are handled by dedicated built-in Core Image filters in `ImageRenderer`
/// since those already model the desired behavior directly.
enum LUTBuilder {
    static let dimension = 24

    static func colorCubeFilter(for edit: EditValues) -> CIFilter? {
        let needsCube = edit.hasHSLEdits
            || !edit.colorGrading.isIdentity
            || edit.saturation != 0
            || edit.vibrance != 0
            || edit.isBlackAndWhite
        guard needsCube else { return nil }

        let dim = dimension
        var cubeData = [Float](repeating: 0, count: dim * dim * dim * 4)

        for bIndex in 0..<dim {
            let b = Float(bIndex) / Float(dim - 1)
            for gIndex in 0..<dim {
                let g = Float(gIndex) / Float(dim - 1)
                for rIndex in 0..<dim {
                    let r = Float(rIndex) / Float(dim - 1)
                    let out = transform(r: r, g: g, b: b, edit: edit)
                    let offset = (bIndex * dim * dim + gIndex * dim + rIndex) * 4
                    cubeData[offset + 0] = out.0
                    cubeData[offset + 1] = out.1
                    cubeData[offset + 2] = out.2
                    cubeData[offset + 3] = 1.0
                }
            }
        }

        let data = cubeData.withUnsafeBufferPointer { Data(buffer: $0) }
        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(dim, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        return filter
    }

    // MARK: - Per-sample transform

    private static func transform(r: Float, g: Float, b: Float, edit: EditValues) -> (Float, Float, Float) {
        var color: (Float, Float, Float) = (r, g, b)

        if edit.hasHSLEdits {
            color = applyHSL(color, edit: edit)
        }
        if edit.saturation != 0 || edit.vibrance != 0 {
            color = applySaturationVibrance(color, saturation: Float(edit.saturation), vibrance: Float(edit.vibrance))
        }
        if !edit.colorGrading.isIdentity {
            color = applyColorGrading(color, grading: edit.colorGrading)
        }
        if edit.isBlackAndWhite {
            let luma = 0.299 * color.0 + 0.587 * color.1 + 0.114 * color.2
            color = (luma, luma, luma)
        }

        return (clampScalar(color.0, 0, 1), clampScalar(color.1, 0, 1), clampScalar(color.2, 0, 1))
    }

    private static func applyHSL(_ color: (Float, Float, Float), edit: EditValues) -> (Float, Float, Float) {
        var hsl = rgbToHSL(color)
        guard hsl.1 > 0.0001 else { return color } // hue undefined for neutral gray

        var hueShift: Float = 0
        var satMultiplier: Float = 1
        var lumOffset: Float = 0

        for band in HSLBandName.allCases {
            guard let adjustment = edit.hsl[band], !adjustment.isIdentity else { continue }
            let weight = hueWeight(pixelHue: hsl.0, bandCenter: Float(band.centerHue))
            guard weight > 0 else { continue }
            hueShift += weight * Float(adjustment.hue) * 0.4
            satMultiplier += weight * Float(adjustment.saturation) / 100
            lumOffset += weight * Float(adjustment.luminance) / 100 * 0.5
        }

        var newHue = (hsl.0 + hueShift).truncatingRemainder(dividingBy: 360)
        if newHue < 0 { newHue += 360 }
        hsl.0 = newHue
        hsl.1 = clampScalar(hsl.1 * max(0, satMultiplier), 0, 1)
        hsl.2 = clampScalar(hsl.2 + lumOffset, 0, 1)

        return hslToRGB(hsl)
    }

    private static func applySaturationVibrance(
        _ color: (Float, Float, Float), saturation: Float, vibrance: Float
    ) -> (Float, Float, Float) {
        var hsl = rgbToHSL(color)
        if saturation != 0 {
            hsl.1 = clampScalar(hsl.1 * (1 + saturation / 100), 0, 1)
        }
        if vibrance != 0 {
            let protection = 1 - hsl.1
            hsl.1 = clampScalar(hsl.1 + (vibrance / 100) * protection * 0.8, 0, 1)
        }
        return hslToRGB(hsl)
    }

    private static func applyColorGrading(
        _ color: (Float, Float, Float), grading: ColorGradingValues
    ) -> (Float, Float, Float) {
        let luma = 0.299 * color.0 + 0.587 * color.1 + 0.114 * color.2
        let balance = Float(grading.balance) / 100

        let shadowWeight = clampScalar(1 - smoothstepScalar(0.15 + max(0, balance) * 0.2, 0.55, luma), 0, 1)
        let highlightWeight = clampScalar(smoothstepScalar(0.45, 0.85 - max(0, -balance) * 0.2, luma), 0, 1)
        let midWeight = clampScalar(1 - shadowWeight - highlightWeight, 0, 1)

        var result = color
        result = blendTint(result, wheel: grading.shadows, weight: shadowWeight, blending: Float(grading.blending))
        result = blendTint(result, wheel: grading.midtones, weight: midWeight, blending: Float(grading.blending))
        result = blendTint(result, wheel: grading.highlights, weight: highlightWeight, blending: Float(grading.blending))
        return result
    }

    private static func blendTint(
        _ color: (Float, Float, Float), wheel: ColorGradingWheel, weight: Float, blending: Float
    ) -> (Float, Float, Float) {
        guard !wheel.isIdentity, weight > 0 else { return color }
        let tintColor = hslToRGB((Float(wheel.hue), 1.0, 0.5))
        let amount = clampScalar(weight * Float(wheel.saturation) / 100 * (0.3 + blending / 100 * 0.7), 0, 1)

        var blended = mixColor(color, tintColor, amount)
        let lumOffset = weight * Float(wheel.luminance) / 100 * 0.4
        blended = (blended.0 + lumOffset, blended.1 + lumOffset, blended.2 + lumOffset)
        return blended
    }

    // MARK: - Color space helpers

    private static func rgbToHSL(_ c: (Float, Float, Float)) -> (Float, Float, Float) {
        let maxV = max(c.0, max(c.1, c.2))
        let minV = min(c.0, min(c.1, c.2))
        let l = (maxV + minV) / 2
        let delta = maxV - minV

        guard delta > 0.00001 else { return (0, 0, l) }

        let s = l < 0.5 ? delta / (maxV + minV) : delta / (2 - maxV - minV)
        var h: Float
        if maxV == c.0 {
            h = ((c.1 - c.2) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxV == c.1 {
            h = (c.2 - c.0) / delta + 2
        } else {
            h = (c.0 - c.1) / delta + 4
        }
        h *= 60
        if h < 0 { h += 360 }
        return (h, s, l)
    }

    private static func hslToRGB(_ hsl: (Float, Float, Float)) -> (Float, Float, Float) {
        var h = hsl.0.truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        let s = hsl.1, l = hsl.2

        guard s > 0.00001 else { return (l, l, l) }

        let c = (1 - abs(2 * l - 1)) * s
        let hPrime = h / 60
        let x = c * (1 - abs(hPrime.truncatingRemainder(dividingBy: 2) - 1))

        var rgb: (Float, Float, Float)
        if hPrime < 1 { rgb = (c, x, 0) }
        else if hPrime < 2 { rgb = (x, c, 0) }
        else if hPrime < 3 { rgb = (0, c, x) }
        else if hPrime < 4 { rgb = (0, x, c) }
        else if hPrime < 5 { rgb = (x, 0, c) }
        else { rgb = (c, 0, x) }

        let m = l - c / 2
        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }

    private static func hueWeight(pixelHue: Float, bandCenter: Float) -> Float {
        var diff = abs(pixelHue - bandCenter)
        if diff > 180 { diff = 360 - diff }
        let width: Float = 45
        guard diff < width else { return 0 }
        return (cos((diff / width) * Float.pi) + 1) / 2
    }

    // MARK: - Generic math helpers

    private static func clampScalar(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(x, lo), hi)
    }

    private static func smoothstepScalar(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
        let t = clampScalar((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private static func mixColor(
        _ a: (Float, Float, Float), _ b: (Float, Float, Float), _ t: Float
    ) -> (Float, Float, Float) {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }
}
