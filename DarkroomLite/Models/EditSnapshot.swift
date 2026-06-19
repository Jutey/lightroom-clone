import Foundation
import SwiftData

/// A named, timestamped snapshot of a photo's full edit state (edit + crop + perspective).
/// Used for the "Snapshots" feature so users can save and recall versions while editing,
/// independent of the linear undo/redo stack.
@Model
final class EditSnapshot {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var editDataBlob: Data
    var cropDataBlob: Data?
    var perspectiveDataBlob: Data?

    var photo: Photo?

    init(name: String, edit: EditValues, crop: CropValues?, perspective: PerspectiveValues?) {
        self.id = UUID()
        self.name = name
        self.dateCreated = .now
        self.editDataBlob = try! JSONEncoder().encode(edit)
        self.cropDataBlob = crop.flatMap { try? JSONEncoder().encode($0) }
        self.perspectiveDataBlob = perspective.flatMap { try? JSONEncoder().encode($0) }
    }

    var edit: EditValues {
        (try? JSONDecoder().decode(EditValues.self, from: editDataBlob)) ?? .identity
    }

    var crop: CropValues? {
        cropDataBlob.flatMap { try? JSONDecoder().decode(CropValues.self, from: $0) }
    }

    var perspective: PerspectiveValues? {
        perspectiveDataBlob.flatMap { try? JSONDecoder().decode(PerspectiveValues.self, from: $0) }
    }
}
