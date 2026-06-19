import Foundation
import SwiftData

/// Persistent, non-destructive edit state for one photo. The actual fields are kept in
/// the Codable `EditValues` struct and stored as encoded data, so every adjustment in
/// the editor automatically gains persistence, presets, copy/paste, and history support
/// without needing a matching SwiftData property for every single slider.
@Model
final class EditSettings {
    var dataBlob: Data
    var dateModified: Date = Date.now

    init(values: EditValues = .identity) {
        self.dataBlob = try! JSONEncoder().encode(values)
    }

    var values: EditValues {
        get { (try? JSONDecoder().decode(EditValues.self, from: dataBlob)) ?? .identity }
        set {
            dataBlob = try! JSONEncoder().encode(newValue)
            dateModified = .now
        }
    }

    func resetAll() {
        values = .identity
    }
}
