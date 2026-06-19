import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import AppKit

/// The single non-destructive render pipeline used everywhere: the live editor preview,
/// the before/after & compare views, and the final export. Given a source image plus the
/// three Codable settings structs (`EditValues`, `CropValues`, `PerspectiveValues`) it always
/// produces the same pixels for the same inputs — nothing here ever touches the original file.
enum ImageRenderer {
    static let sharedContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Loading source pixels

    static func loadSourceImage(url: URL, isRaw: Bool, draft: Bool) -> CIImage? {
        if isRaw {
            return RawSupport.ciImage(contentsOf: url, draft: draft)
        }
        return CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    }

    // MARK: - Full pipeline

    /// Applies lens correction, geometry (perspective/rotate/flip/straighten/crop), then
    /// every tone/color/effect/detail adjustment, in that order.
    static func render(
        source: CIImage,
        edit: EditValues,
        crop: CropValues,
        perspective: PerspectiveValues,
        cachedColorCube: CIFilter? = nil
    ) -> CIImage {
        var image = source
        image = applyLensCorrections(image, lens: edit.lens)
        image = applyGeometry(image, crop: crop, perspective: perspective)
        image = applyToneAndColor(image, edit: edit, cachedColorCube: cachedColorCube)
        image = applyEffectsAndDetail(image, edit: edit)
        return image
    }

    /// Geometry only (used by the crop/perspective tools to preview the canvas before
    /// committing, without paying the cost of re-running every color filter).
    static func applyGeometry(_ image: CIImage, crop: CropValues, perspective: PerspectiveValues) -> CIImage {
        var result = image
        result = applyPerspective(result, perspective: perspective)
        result = rotated90(result, quarterTurns: crop.rotationQuarterTurns)
        result = flipped(result, horizontal: crop.flipHorizontal, vertical: crop.flipVertical)
        result = straightened(result, degrees: crop.straightenAngle)
        result = cropped(result, normalizedRect: crop.normalizedRect)
        return result
    }

    // MARK: - Rendering to bitmaps

    static func renderToCGImage(_ image: CIImage, context: CIContext = sharedContext) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }

    static func renderToNSImage(_ image: CIImage, context: CIContext = sharedContext) -> NSImage? {
        guard let cgImage = renderToCGImage(image, context: context) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Downsamples `image` so its longest side is at most `maxDimension`, for fast
    /// interactive previews. Pass `maxDimension <= 0` to skip downsampling.
    static func downsampled(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        guard maxDimension > 0 else { return image }
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    // MARK: - Lens corrections (simplified)

    private static func applyLensCorrections(_ image: CIImage, lens: LensValues) -> CIImage {
        guard !lens.isIdentity else { return image }
        var result = image
        let extent = result.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)

        if lens.distortion != 0 {
            let filter = CIFilter.bumpDistortion()
            filter.inputImage = result
            filter.center = center
            filter.radius = Float(min(extent.width, extent.height))
            filter.scale = Float(lens.distortion / 100) * 0.35
            result = filter.outputImage?.cropped(to: extent) ?? result
        }

        if lens.vignetteCorrection != 0 {
            let filter = CIFilter.vignetteEffect()
            filter.inputImage = result
            filter.center = center
            filter.radius = Float(min(extent.width, extent.height)) * 0.6
            filter.intensity = -Float(lens.vignetteCorrection / 100) * 0.8
            filter.falloff = 0.5
            result = filter.outputImage?.cropped(to: extent) ?? result
        }

        if lens.removeChromaticAberration {
            result = removeChromaticAberration(result)
        }

        return result
    }

    private enum ColorChannel { case red, green, blue }

    /// Crude but real CA reduction: isolates the red and blue channels and shrinks them
    /// very slightly toward the image center to pull fringing back into alignment with green.
    private static func removeChromaticAberration(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let shift: CGFloat = 0.0015
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)

        func isolatedChannel(_ channel: ColorChannel) -> CIImage {
            let isolate = CIFilter.colorMatrix()
            isolate.inputImage = image
            isolate.rVector = channel == .red ? CIVector(x: 1, y: 0, z: 0, w: 0) : zero
            isolate.gVector = channel == .green ? CIVector(x: 0, y: 1, z: 0, w: 0) : zero
            isolate.bVector = channel == .blue ? CIVector(x: 0, y: 0, z: 1, w: 0) : zero
            isolate.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            return isolate.outputImage ?? image
        }

        func scaled(_ layer: CIImage, scale: CGFloat) -> CIImage {
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let scaleT = CGAffineTransform(scaleX: scale, y: scale)
            let back = CGAffineTransform(translationX: center.x, y: center.y)
            return layer.transformed(by: toOrigin.concatenating(scaleT).concatenating(back))
        }

        let redLayer = scaled(isolatedChannel(.red), scale: 1 - shift)
        let greenLayer = isolatedChannel(.green)
        let blueLayer = scaled(isolatedChannel(.blue), scale: 1 + shift)

        let addRG = CIFilter.additionCompositing()
        addRG.inputImage = redLayer
        addRG.backgroundImage = greenLayer
        let addB = CIFilter.additionCompositing()
        addB.inputImage = blueLayer
        addB.backgroundImage = addRG.outputImage ?? image
        return (addB.outputImage ?? image).cropped(to: extent)
    }

    // MARK: - Geometry

    private static func applyPerspective(_ image: CIImage, perspective: PerspectiveValues) -> CIImage {
        var result = image
        if !(perspective.verticalPerspective == 0 && perspective.horizontalPerspective == 0) {
            let extent = result.extent
            let w = extent.width, h = extent.height
            let vShift = CGFloat(perspective.verticalPerspective / 100) * 0.4 * w
            let hShift = CGFloat(perspective.horizontalPerspective / 100) * 0.4 * h

            let topLeft = CGPoint(x: extent.minX - vShift, y: extent.maxY)
            let topRight = CGPoint(x: extent.maxX + vShift, y: extent.maxY + hShift)
            let bottomLeft = CGPoint(x: extent.minX, y: extent.minY)
            let bottomRight = CGPoint(x: extent.maxX, y: extent.minY - hShift)

            let filter = CIFilter.perspectiveCorrection()
            filter.inputImage = result
            filter.topLeft = topLeft
            filter.topRight = topRight
            filter.bottomLeft = bottomLeft
            filter.bottomRight = bottomRight
            filter.crop = false
            if let output = filter.outputImage {
                result = output
            }
        }

        if perspective.rotation != 0 {
            result = straightened(result, degrees: perspective.rotation)
        }

        if perspective.scale != 100 {
            let extent = result.extent
            let center = CGPoint(x: extent.midX, y: extent.midY)
            let s = CGFloat(perspective.scale / 100)
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let scale = CGAffineTransform(scaleX: s, y: s)
            let back = CGAffineTransform(translationX: center.x, y: center.y)
            result = result.transformed(by: toOrigin.concatenating(scale).concatenating(back))
        }

        return result
    }

    private static func rotated90(_ image: CIImage, quarterTurns: Int) -> CIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns > 0 else { return image }
        var result = image
        for _ in 0..<turns {
            let extent = result.extent
            let center = CGPoint(x: extent.midX, y: extent.midY)
            let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
            let rotate = CGAffineTransform(rotationAngle: -.pi / 2)
            let back = CGAffineTransform(translationX: center.x, y: center.y)
            result = result.transformed(by: toOrigin.concatenating(rotate).concatenating(back))
        }
        return result
    }

    private static func flipped(_ image: CIImage, horizontal: Bool, vertical: Bool) -> CIImage {
        guard horizontal || vertical else { return image }
        let extent = image.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let sx: CGFloat = horizontal ? -1 : 1
        let sy: CGFloat = vertical ? -1 : 1
        let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
        let scale = CGAffineTransform(scaleX: sx, y: sy)
        let back = CGAffineTransform(translationX: center.x, y: center.y)
        return image.transformed(by: toOrigin.concatenating(scale).concatenating(back))
    }

    static func straightened(_ image: CIImage, degrees: Double) -> CIImage {
        guard degrees != 0 else { return image }
        let extent = image.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let radians = CGFloat(degrees) * .pi / 180
        let toOrigin = CGAffineTransform(translationX: -center.x, y: -center.y)
        let rotate = CGAffineTransform(rotationAngle: radians)
        let back = CGAffineTransform(translationX: center.x, y: center.y)
        return image.transformed(by: toOrigin.concatenating(rotate).concatenating(back))
    }

    static func cropped(_ image: CIImage, normalizedRect: CGRect) -> CIImage {
        guard normalizedRect != CGRect(x: 0, y: 0, width: 1, height: 1) else { return image }
        let extent = image.extent
        let rect = CGRect(
            x: extent.origin.x + normalizedRect.origin.x * extent.width,
            y: extent.origin.y + normalizedRect.origin.y * extent.height,
            width: max(1, normalizedRect.width * extent.width),
            height: max(1, normalizedRect.height * extent.height)
        )
        return image.cropped(to: rect.intersection(extent))
    }

    // MARK: - Tone & color

    private static func applyToneAndColor(_ image: CIImage, edit: EditValues, cachedColorCube: CIFilter?) -> CIImage {
        var result = image

        if edit.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = result
            filter.ev = Float(edit.exposure)
            result = filter.outputImage ?? result
        }

        if edit.contrast != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.contrast = Float(1 + edit.contrast / 100 * 0.75)
            filter.saturation = 1
            filter.brightness = 0
            result = filter.outputImage ?? result
        }

        if edit.blacks != 0 || edit.shadows != 0 || edit.highlights != 0 || edit.whites != 0 {
            result = applyToneCurve(result, points: lightToneCurvePoints(edit: edit))
        }

        if edit.temperature != 0 || edit.tint != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = result
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(
                x: 6500 - CGFloat(edit.temperature) * 20,
                y: CGFloat(edit.tint) * 10
            )
            result = filter.outputImage ?? result
        }

        if edit.hasToneCurveEdit {
            result = applyToneCurve(result, points: edit.toneCurve)
        }

        let colorCube = cachedColorCube ?? LUTBuilder.colorCubeFilter(for: edit)
        if let colorCube {
            colorCube.setValue(result, forKey: kCIInputImageKey)
            result = colorCube.outputImage ?? result
        }

        return result
    }

    private static func lightToneCurvePoints(edit: EditValues) -> [CurvePoint] {
        func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
        return [
            CurvePoint(x: 0, y: clamp01(0 + edit.blacks / 100 * 0.2)),
            CurvePoint(x: 0.25, y: clamp01(0.25 + edit.shadows / 100 * 0.2)),
            CurvePoint(x: 0.5, y: 0.5),
            CurvePoint(x: 0.75, y: clamp01(0.75 + edit.highlights / 100 * 0.2)),
            CurvePoint(x: 1, y: clamp01(1 + edit.whites / 100 * 0.2)),
        ]
    }

    private static func applyToneCurve(_ image: CIImage, points: [CurvePoint]) -> CIImage {
        guard points.count == 5 else { return image }
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: points[0].x, y: points[0].y)
        filter.point1 = CGPoint(x: points[1].x, y: points[1].y)
        filter.point2 = CGPoint(x: points[2].x, y: points[2].y)
        filter.point3 = CGPoint(x: points[3].x, y: points[3].y)
        filter.point4 = CGPoint(x: points[4].x, y: points[4].y)
        return filter.outputImage ?? image
    }

    // MARK: - Effects & detail

    private static func applyEffectsAndDetail(_ image: CIImage, edit: EditValues) -> CIImage {
        var result = image

        if edit.texture != 0 {
            result = applyTextureClarity(result, amount: edit.texture, radius: 2.5)
        }
        if edit.clarity != 0 {
            result = applyTextureClarity(result, amount: edit.clarity, radius: 30)
        }
        if edit.dehaze != 0 {
            result = applyDehaze(result, amount: edit.dehaze)
        }
        if edit.noiseReduction != 0 || edit.colorNoiseReduction != 0 {
            let filter = CIFilter.noiseReduction()
            filter.inputImage = result
            filter.noiseLevel = Float(edit.noiseReduction / 100) * 0.1
            filter.sharpness = Float(max(0, 2 - edit.colorNoiseReduction / 100 * 2))
            result = filter.outputImage ?? result
        }
        if edit.sharpness != 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = result
            filter.sharpness = Float(edit.sharpness / 100) * 2.0
            filter.radius = Float(edit.sharpenRadius)
            result = filter.outputImage ?? result
        }
        if edit.vignetteAmount != 0 {
            result = applyArtisticVignette(result, edit: edit)
        }
        if edit.grainAmount != 0 {
            result = applyGrain(result, edit: edit)
        }

        return result
    }

    private static func applyTextureClarity(_ image: CIImage, amount: Double, radius: Double) -> CIImage {
        let extent = image.extent
        if amount > 0 {
            let filter = CIFilter.unsharpMask()
            filter.inputImage = image
            filter.radius = Float(radius)
            filter.intensity = Float(amount / 100) * 0.6
            return (filter.outputImage ?? image).cropped(to: extent)
        } else {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image.clampedToExtent()
            blur.radius = Float(-amount / 100) * Float(radius) * 0.6
            let blurred = (blur.outputImage ?? image).cropped(to: extent)
            return dissolve(base: image, overlay: blurred, amount: -amount / 100 * 0.6)
        }
    }

    private static func applyDehaze(_ image: CIImage, amount: Double) -> CIImage {
        let extent = image.extent
        if amount > 0 {
            let contrast = CIFilter.colorControls()
            contrast.inputImage = image
            contrast.contrast = Float(1 + amount / 100 * 0.2)
            contrast.saturation = Float(1 + amount / 100 * 0.1)
            contrast.brightness = 0
            let contrasted = contrast.outputImage ?? image

            let unsharp = CIFilter.unsharpMask()
            unsharp.inputImage = contrasted
            unsharp.radius = 50
            unsharp.intensity = Float(amount / 100) * 0.35
            return (unsharp.outputImage ?? contrasted).cropped(to: extent)
        } else {
            let fogImage = CIImage(color: CIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)).cropped(to: extent)
            return dissolve(base: image, overlay: fogImage, amount: -amount / 100 * 0.35)
        }
    }

    private static func applyArtisticVignette(_ image: CIImage, edit: EditValues) -> CIImage {
        let extent = image.extent
        let filter = CIFilter.vignetteEffect()
        filter.inputImage = image
        filter.center = CGPoint(x: extent.midX, y: extent.midY)
        filter.radius = Float(min(extent.width, extent.height)) * Float(0.3 + edit.vignetteMidpoint / 100 * 0.5)
        filter.intensity = Float(edit.vignetteAmount / 100)
        filter.falloff = Float(0.2 + edit.vignetteFeather / 100 * 1.3)
        return (filter.outputImage ?? image).cropped(to: extent)
    }

    private static func applyGrain(_ image: CIImage, edit: EditValues) -> CIImage {
        let extent = image.extent
        let random = CIFilter.randomGenerator()
        guard let noise = random.outputImage?.cropped(to: extent) else { return image }

        let desaturate = CIFilter.colorControls()
        desaturate.inputImage = noise
        desaturate.saturation = 0
        desaturate.contrast = 1
        desaturate.brightness = 0

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = (desaturate.outputImage ?? noise).clampedToExtent()
        blur.radius = Float(0.2 + edit.grainSize / 100 * 1.8)
        let softened = (blur.outputImage ?? noise).cropped(to: extent)

        // Pull the noise toward mid-gray, then scale its deviation by the grain amount so the
        // slider controls visible strength even though the blend mode itself has no opacity.
        let amount = Float(edit.grainAmount / 100)
        let scaleMatrix = CIFilter.colorMatrix()
        scaleMatrix.inputImage = softened
        scaleMatrix.rVector = CIVector(x: CGFloat(amount), y: 0, z: 0, w: 0)
        scaleMatrix.gVector = CIVector(x: 0, y: CGFloat(amount), z: 0, w: 0)
        scaleMatrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(amount), w: 0)
        scaleMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        scaleMatrix.biasVector = CIVector(x: CGFloat(0.5 * (1 - amount)), y: CGFloat(0.5 * (1 - amount)), z: CGFloat(0.5 * (1 - amount)), w: 0)

        let blend = CIFilter.hardLightBlendMode()
        blend.inputImage = scaleMatrix.outputImage ?? softened
        blend.backgroundImage = image
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    private static func dissolve(base: CIImage, overlay: CIImage, amount: Double) -> CIImage {
        let clampedAmount = Float(min(max(amount, 0), 1))
        let alphaMatrix = CIFilter.colorMatrix()
        alphaMatrix.inputImage = overlay
        alphaMatrix.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        alphaMatrix.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        alphaMatrix.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
        alphaMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(clampedAmount))

        let blend = CIFilter.sourceOverCompositing()
        blend.inputImage = alphaMatrix.outputImage ?? overlay
        blend.backgroundImage = base
        return blend.outputImage ?? base
    }
}
