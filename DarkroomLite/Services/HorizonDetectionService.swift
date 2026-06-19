import Foundation
import Vision
import CoreImage

/// Wraps Vision's horizon detector to power the crop tool's "Auto Straighten" button.
enum HorizonDetectionService {
    /// Returns the detected horizon angle in degrees (positive = rotate clockwise to level it),
    /// or nil if Vision couldn't find a confident horizon in the image.
    static func detectAngle(in image: CIImage) -> Double? {
        let request = VNDetectHorizonRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return nil }
            // VNHorizonObservation.angle is in radians, counter-clockwise positive.
            let degrees = Double(result.angle) * 180 / .pi
            return -degrees
        } catch {
            return nil
        }
    }
}
