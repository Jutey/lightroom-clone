import Foundation
import SwiftData

/// A collection inside a project, similar to a Lightroom collection. A photo can
/// belong to any number of albums within its parent project.
@Model
final class Album {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var sortOrder: Int

    var project: Project?

    @Relationship(inverse: \Photo.albums)
    var photos: [Photo]? = []

    init(name: String, project: Project? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.project = project
        self.dateCreated = .now
        self.sortOrder = sortOrder
    }

    var photoCount: Int { photos?.count ?? 0 }
}
