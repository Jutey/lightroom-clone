import Foundation
import SwiftData

struct PerspectiveValues: Codable, Equatable, Sendable {
    var verticalPerspective: Double = 0    // -100...100
    var horizontalPerspective: Double = 0  // -100...100
    var rotation: Double = 0               // -45...45 degrees, fine angle correction
    var scale: Double = 100                // 50...150, fills frame after transform

    static let identity = PerspectiveValues()

    var isIdentity: Bool { self == PerspectiveValues() }
}

/// Persistent, non-destructive perspective/transform correction state for one photo.
@Model
final class PerspectiveSettings {
    var dataBlob: Data
    var isApplied: Bool = false
    var dateModified: Date = Date.now

    init(values: PerspectiveValues = .identity) {
        self.dataBlob = try! JSONEncoder().encode(values)
    }

    var values: PerspectiveValues {
        get { (try? JSONDecoder().decode(PerspectiveValues.self, from: dataBlob)) ?? .identity }
        set {
            dataBlob = try! JSONEncoder().encode(newValue)
            dateModified = .now
        }
    }
}
