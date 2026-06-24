import Foundation
import CoreImage

/// Parses Adobe/Resolve-style `.cube` 3D LUT files into a `CIColorCube`-ready buffer.
/// Only 3D LUTs (`LUT_3D_SIZE`) are supported — 1D LUTs are rejected with a clear error
/// rather than silently misinterpreted. The file's data rows already use the same
/// "red fastest-varying, blue slowest-varying" axis order that `CIColorCube` expects, so
/// rows are written straight into the output buffer with no reordering.
enum CubeLUTParser {
    struct ParsedLUT {
        let dimension: Int
        let data: Data // RGBA Float32, dimension^3 * 4 floats, alpha always 1.0
    }

    enum ParseError: LocalizedError {
        case unreadable
        case missingSize
        case unsupportedDimension(Int)
        case insufficientData(expected: Int, found: Int)
        case only1DSupported

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The file couldn't be read as a text-based .cube LUT."
            case .missingSize:
                return "No LUT_3D_SIZE entry was found in this file."
            case .unsupportedDimension(let n):
                return "Unsupported LUT size (\(n)). Expected a cube size between 2 and 256."
            case .insufficientData(let expected, let found):
                return "Expected \(expected) data rows but found \(found)."
            case .only1DSupported:
                return "This file is a 1D LUT. Only 3D LUTs (LUT_3D_SIZE) are supported."
            }
        }
    }

    static func parse(url: URL) -> Result<ParsedLUT, ParseError> {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return .failure(.unreadable)
        }
        return parse(text: text)
    }

    static func parse(text: String) -> Result<ParsedLUT, ParseError> {
        var dimension: Int?
        var saw1DSize = false
        var values: [Float] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 2 { dimension = Int(parts[1]) }
                continue
            }
            if line.hasPrefix("LUT_1D_SIZE") {
                saw1DSize = true
                continue
            }
            if line.hasPrefix("TITLE") || line.hasPrefix("DOMAIN_MIN") || line.hasPrefix("DOMAIN_MAX") {
                continue
            }

            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let r = Float(parts[0]), let g = Float(parts[1]), let b = Float(parts[2])
            else { continue }
            values.append(r)
            values.append(g)
            values.append(b)
            values.append(1.0)
        }

        guard let dimension else {
            return .failure(saw1DSize ? .only1DSupported : .missingSize)
        }
        guard dimension >= 2, dimension <= 256 else {
            return .failure(.unsupportedDimension(dimension))
        }

        let expectedRows = dimension * dimension * dimension
        guard values.count == expectedRows * 4 else {
            return .failure(.insufficientData(expected: expectedRows, found: values.count / 4))
        }

        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return .success(ParsedLUT(dimension: dimension, data: data))
    }

    static func colorCubeFilter(from parsed: ParsedLUT) -> CIFilter? {
        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(parsed.dimension, forKey: "inputCubeDimension")
        filter?.setValue(parsed.data, forKey: "inputCubeData")
        return filter
    }

    /// Convenience for call sites that only care whether a usable filter could be built,
    /// not the specific parse failure (e.g. rebuilding a render-time cache after relaunch).
    static func colorCubeFilter(at url: URL) -> CIFilter? {
        guard case .success(let parsed) = parse(url: url) else { return nil }
        return colorCubeFilter(from: parsed)
    }
}
