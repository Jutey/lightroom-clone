import SwiftUI
import SwiftData

/// Hosts the grid/loupe/compare/before-after viewers plus the filter bar and filmstrip for
/// whichever project is selected in the sidebar. Owns the SwiftData `@Query` for that
/// project's photos so imports/edits/trash propagate automatically; `LibraryViewModel` just
/// decides which of those photos are shown, in what order, and which are selected.
struct ProjectWorkspaceView: View {
    @Environment(AppController.self) private var app
    let project: Project

    @Query private var photos: [Photo]

    init(project: Project) {
        self.project = project
        // Compare on the stable UUID rather than the model instance: #Predicate can't
        // expand an equality check between two PersistentModel instances directly.
        let projectID = project.id
        _photos = Query(filter: #Predicate<Photo> { $0.project?.id == projectID }, sort: \Photo.importOrder)
    }

    private var albumFilteredPhotos: [Photo] {
        guard let album = app.library.selectedAlbum else { return photos }
        return photos.filter { photo in
            photo.albums?.contains(where: { $0.id == album.id }) ?? false
        }
    }

    /// Bundles every input that should re-run filtering/sorting into one Equatable value so
    /// a single `onChange` can drive `LibraryViewModel.syncDisplayedPhotos(_:)`.
    private struct FilterSnapshot: Equatable {
        var photos: [Photo]
        var album: Album?
        var search: String
        var rating: Int
        var flag: PickFlag?
        var colorLabel: ColorLabelTag?
        var editedOnly: Bool
        var fileType: LibraryViewModel.FileTypeFilter
        var sortOrder: LibrarySortOrder
        var showTrashed: Bool
    }

    private var filterSnapshot: FilterSnapshot {
        FilterSnapshot(
            photos: albumFilteredPhotos,
            album: app.library.selectedAlbum,
            search: app.library.searchText,
            rating: app.library.ratingFilter,
            flag: app.library.flagFilter,
            colorLabel: app.library.colorLabelFilter,
            editedOnly: app.library.editedOnlyFilter,
            fileType: app.library.fileTypeFilter,
            sortOrder: app.library.sortOrder,
            showTrashed: app.library.showTrashed
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterBarView()
            Divider()
            Group {
                switch app.library.viewMode {
                case .grid:
                    GridView(photos: app.library.displayedPhotos, projectFolderBookmark: project.folderBookmark)
                case .loupe:
                    LoupeView(projectFolderBookmark: project.folderBookmark)
                case .compare:
                    CompareView(photos: app.library.displayedPhotos, projectFolderBookmark: project.folderBookmark)
                case .beforeAfter:
                    BeforeAfterView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if app.library.viewMode != .grid {
                Divider()
                FilmstripView(photos: app.library.displayedPhotos, projectFolderBookmark: project.folderBookmark)
            }
        }
        .onChange(of: filterSnapshot, initial: true) { _, snapshot in
            app.library.syncDisplayedPhotos(snapshot.photos)
        }
    }
}
