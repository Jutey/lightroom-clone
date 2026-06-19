import Foundation
import SwiftData

/// A "project" is a folder the user imported. All photos found inside that folder
/// (and its subfolders) belong to the project. Projects never modify or move the
/// original files — we only ever read from `folderBookmark`.
@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var folderPath: String
    var folderBookmark: Data?
    var dateCreated: Date
    var dateModified: Date
    var sortOrder: Int
    var includesSubfolders: Bool

    @Relationship(deleteRule: .cascade, inverse: \Photo.project)
    var photos: [Photo]? = []

    @Relationship(deleteRule: .cascade, inverse: \Album.project)
    var albums: [Album]? = []

    init(
        name: String,
        folderPath: String,
        folderBookmark: Data? = nil,
        sortOrder: Int = 0,
        includesSubfolders: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.folderPath = folderPath
        self.folderBookmark = folderBookmark
        self.dateCreated = .now
        self.dateModified = .now
        self.sortOrder = sortOrder
        self.includesSubfolders = includesSubfolders
    }

    var photoCount: Int { photos?.count ?? 0 }

    var pickedCount: Int {
        photos?.filter { $0.flag == .picked }.count ?? 0
    }
}
