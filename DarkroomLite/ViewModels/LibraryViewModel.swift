import Foundation
import Observation

/// Filtering, sorting, view-mode, and selection state for whichever project's photo
/// grid/filmstrip is currently on screen. Views own the SwiftData `@Query` for the actual
/// `Photo` array (so changes propagate automatically); this view model just decides which
/// of those photos are shown, in what order, and which ones are selected/active.
@MainActor
@Observable
final class LibraryViewModel {
    enum FileTypeFilter: String, CaseIterable, Identifiable {
        case all, standard, raw
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All Types"
            case .standard: return "Standard"
            case .raw: return "RAW"
            }
        }
    }

    var selectedProject: Project?
    var selectedAlbum: Album?

    var viewMode: ViewMode = .grid
    var activeTool: ActiveTool = .none
    var activePhoto: Photo?
    var selectedPhotoIDs: Set<UUID> = []
    var comparePhotoID: UUID?

    var searchText: String = ""
    var ratingFilter: Int = 0
    var flagFilter: PickFlag?
    var colorLabelFilter: ColorLabelTag?
    var editedOnlyFilter: Bool = false
    var fileTypeFilter: FileTypeFilter = .all
    var sortOrder: LibrarySortOrder = .captureDateNewest
    var showTrashed: Bool = false

    /// The current project's photos after filtering/sorting. Kept in sync by the view
    /// whenever its `@Query` results or the filter/sort criteria above change.
    private(set) var displayedPhotos: [Photo] = []

    var pendingDeleteConfirmation: [Photo]?
    var pendingBatchApplyConfirmation: (() -> Void)?
    var pendingBatchApplyCount: Int = 0

    /// Set when the user tries to leave the crop/perspective tool with unconfirmed geometry
    /// changes and `warnBeforeDiscardingGeometryChanges` is on. `proceed()` discards the
    /// changes and completes whatever tool/photo switch was requested.
    struct PendingGeometryDiscard {
        let toolBeingExited: ActiveTool
        let proceed: () -> Void
    }
    var pendingGeometryDiscardConfirmation: PendingGeometryDiscard?

    var hasActiveFilters: Bool {
        !searchText.isEmpty || ratingFilter > 0 || flagFilter != nil || colorLabelFilter != nil
            || editedOnlyFilter || fileTypeFilter != .all
    }

    func clearFilters() {
        searchText = ""
        ratingFilter = 0
        flagFilter = nil
        colorLabelFilter = nil
        editedOnlyFilter = false
        fileTypeFilter = .all
    }

    func filteredAndSorted(_ photos: [Photo]) -> [Photo] {
        var result = photos.filter { $0.isTrashed == showTrashed }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.fileName.lowercased().contains(query)
                    || ($0.cameraModel?.lowercased().contains(query) ?? false)
                    || ($0.lensModel?.lowercased().contains(query) ?? false)
            }
        }
        if ratingFilter > 0 {
            result = result.filter { $0.rating >= ratingFilter }
        }
        if let flagFilter {
            result = result.filter { $0.flag == flagFilter }
        }
        if let colorLabelFilter {
            result = result.filter { $0.colorLabel == colorLabelFilter }
        }
        if editedOnlyFilter {
            result = result.filter { $0.hasEdits }
        }
        switch fileTypeFilter {
        case .all: break
        case .standard: result = result.filter { !$0.isRaw }
        case .raw: result = result.filter { $0.isRaw }
        }

        switch sortOrder {
        case .captureDateNewest:
            result.sort { ($0.captureDate ?? $0.importDate) > ($1.captureDate ?? $1.importDate) }
        case .captureDateOldest:
            result.sort { ($0.captureDate ?? $0.importDate) < ($1.captureDate ?? $1.importDate) }
        case .fileName:
            result.sort { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        case .rating:
            result.sort { $0.rating > $1.rating }
        case .importOrder:
            result.sort { $0.importOrder < $1.importOrder }
        }
        return result
    }

    func syncDisplayedPhotos(_ photos: [Photo]) {
        displayedPhotos = filteredAndSorted(photos)
        if let activePhoto, !displayedPhotos.contains(where: { $0.id == activePhoto.id }) {
            self.activePhoto = displayedPhotos.first
        }
        if activePhoto == nil {
            activePhoto = displayedPhotos.first
        }
        selectedPhotoIDs = selectedPhotoIDs.filter { id in displayedPhotos.contains { $0.id == id } }
    }

    func selectedPhotos(in all: [Photo]) -> [Photo] {
        all.filter { selectedPhotoIDs.contains($0.id) }
    }

    func selectOnly(_ photo: Photo) {
        selectedPhotoIDs = [photo.id]
        activePhoto = photo
    }

    func toggleSelection(_ photo: Photo, extend: Bool) {
        guard extend else {
            selectOnly(photo)
            return
        }
        if selectedPhotoIDs.contains(photo.id) {
            selectedPhotoIDs.remove(photo.id)
        } else {
            selectedPhotoIDs.insert(photo.id)
        }
        activePhoto = photo
    }

    func selectRange(to photo: Photo) {
        guard let anchor = activePhoto,
              let anchorIndex = displayedPhotos.firstIndex(where: { $0.id == anchor.id }),
              let targetIndex = displayedPhotos.firstIndex(where: { $0.id == photo.id }) else {
            selectOnly(photo)
            return
        }
        let range = anchorIndex < targetIndex ? anchorIndex...targetIndex : targetIndex...anchorIndex
        for photo in displayedPhotos[range] {
            selectedPhotoIDs.insert(photo.id)
        }
        activePhoto = photo
    }

    func selectAll() {
        selectedPhotoIDs = Set(displayedPhotos.map(\.id))
    }

    func selectAdjacent(by delta: Int) {
        guard !displayedPhotos.isEmpty else { return }
        guard let activePhoto, let index = displayedPhotos.firstIndex(where: { $0.id == activePhoto.id }) else {
            selectOnly(displayedPhotos[0])
            return
        }
        let newIndex = (index + delta).clamped(to: 0...(displayedPhotos.count - 1))
        selectOnly(displayedPhotos[newIndex])
    }

    func selectNext() { selectAdjacent(by: 1) }
    func selectPrevious() { selectAdjacent(by: -1) }
}
