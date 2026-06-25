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
            if app.library.viewMode.workspaceTab == .pick {
                FilterBarView()
                Divider()
            }
            Group {
                switch app.library.viewMode {
                case .grid:
                    GridView(photos: app.library.displayedPhotos, projectFolderBookmark: project.folderBookmark)
                case .loupe:
                    if isActivePhotoEditable {
                        LoupeView(projectFolderBookmark: project.folderBookmark)
                    } else {
                        noPickedPhotoPlaceholder
                    }
                case .compare:
                    CompareView(photos: app.library.displayedPhotos, projectFolderBookmark: project.folderBookmark)
                case .beforeAfter:
                    if isActivePhotoEditable {
                        BeforeAfterView()
                    } else {
                        noPickedPhotoPlaceholder
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if app.library.viewMode != .grid {
                Divider()
                FilmstripView(photos: app.library.editablePhotos, projectFolderBookmark: project.folderBookmark)
            }
        }
        .onChange(of: filterSnapshot, initial: true) { _, snapshot in
            app.library.syncDisplayedPhotos(snapshot.photos)
        }
    }

    /// Only reached for `.loupe`/`.beforeAfter` (the Edit tab's two modes), where only a
    /// Picked photo is editable — if the active photo loses its pick flag (or none has ever
    /// been picked), this gates Loupe/Before-After off rather than silently letting an
    /// unpicked photo be edited.
    private var isActivePhotoEditable: Bool {
        app.library.activePhoto?.flag == .picked
    }

    private var noPickedPhotoPlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No Picked Photo")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Pick a photo (P) in Grid or Compare before editing it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
