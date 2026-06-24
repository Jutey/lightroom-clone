import CoreImage
import CoreImage.CIFilterBuiltins

/// A snapshot of a rendered image's per-channel tonal distribution, computed via Core Image's
/// `CIAreaHistogram` filter so the live preview can show a Lightroom-style RGB histogram with
/// shadow/highlight clipping warnings.
struct HistogramData: Equatable {
    static let binCount = 256

    var red: [Float]
    var green: [Float]
    var blue: [Float]

    /// Fraction (0...1) of pixels in the most-clipped channel sitting at the very bottom/top
    /// bin — an approximation of Lightroom's clipping triangles, computed from independent
    /// per-channel histograms rather than joint per-pixel channel values.
    var blackClipFraction: Double
    var whiteClipFraction: Double
}

enum HistogramService {
    static func compute(from image: CIImage, context: CIContext) -> HistogramData? {
        let extent = image.extent
        guard extent.origin.x.isFinite, extent.origin.y.isFinite,
              extent.width.isFinite, extent.height.isFinite,
              !extent.isEmpty else { return nil }

        let binCount = HistogramData.binCount
        let filter = CIFilter.areaHistogram()
        filter.inputImage = image
        filter.extent = extent
        filter.scale = 1
        filter.count = binCount

        guard let histogramImage = filter.outputImage else { return nil }

        var pixels = [Float](repeating: 0, count: binCount * 4)
        pixels.withUnsafeMutableBytes { buffer in
            context.render(
                histogramImage,
                toBitmap: buffer.baseAddress!,
                rowBytes: binCount * 4 * MemoryLayout<Float>.size,
                bounds: CGRect(x: 0, y: 0, width: binCount, height: 1),
                format: .RGBAf,
                colorSpace: nil
            )
        }

        var red = [Float](repeating: 0, count: binCount)
        var green = [Float](repeating: 0, count: binCount)
        var blue = [Float](repeating: 0, count: binCount)
        for i in 0..<binCount {
            red[i] = pixels[i * 4]
            green[i] = pixels[i * 4 + 1]
            blue[i] = pixels[i * 4 + 2]
        }

        let peak = max(red.max() ?? 0, green.max() ?? 0, blue.max() ?? 0)
        func normalized(_ values: [Float]) -> [Float] {
            guard peak > 0 else { return values }
            return values.map { $0 / peak }
        }

        let totalPixels = Double(red.reduce(0, +))
        let blackClip = Double(max(red[0], green[0], blue[0]))
        let whiteClip = Double(max(red[binCount - 1], green[binCount - 1], blue[binCount - 1]))

        return HistogramData(
            red: normalized(red), green: normalized(green), blue: normalized(blue),
            blackClipFraction: totalPixels > 0 ? blackClip / totalPixels : 0,
            whiteClipFraction: totalPixels > 0 ? whiteClip / totalPixels : 0
        )
    }
}
