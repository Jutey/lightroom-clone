import Foundation
import SwiftData

/// A user-created (or built-in) named bundle of edit values that can be applied to any photo.
@Model
final class Preset {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var dataBlob: Data
    var isBuiltIn: Bool
    var sortOrder: Int

    init(name: String, values: EditValues, isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.dateCreated = .now
        self.dataBlob = try! JSONEncoder().encode(values)
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }

    var values: EditValues {
        get { (try? JSONDecoder().decode(EditValues.self, from: dataBlob)) ?? .identity }
        set { dataBlob = try! JSONEncoder().encode(newValue) }
    }

    /// A handful of starter presets so the Presets panel isn't empty on first launch.
    static func builtInDefaults() -> [Preset] {
        var bw = EditValues.identity
        bw.isBlackAndWhite = true
        bw.contrast = 12
        bw.clarity = 8

        var warm = EditValues.identity
        warm.temperature = 18
        warm.vibrance = 10

        var cool = EditValues.identity
        cool.temperature = -16
        cool.tint = 4

        var punchy = EditValues.identity
        punchy.contrast = 18
        punchy.vibrance = 22
        punchy.clarity = 14
        punchy.shadows = 8

        var faded = EditValues.identity
        faded.blacks = 14
        faded.contrast = -8
        faded.saturation = -10
        faded.vignetteAmount = 8

        return [
            Preset(name: "Black & White", values: bw, isBuiltIn: true, sortOrder: 0),
            Preset(name: "Warm", values: warm, isBuiltIn: true, sortOrder: 1),
            Preset(name: "Cool", values: cool, isBuiltIn: true, sortOrder: 2),
            Preset(name: "Punchy", values: punchy, isBuiltIn: true, sortOrder: 3),
            Preset(name: "Faded Film", values: faded, isBuiltIn: true, sortOrder: 4),
        ]
    }
}
