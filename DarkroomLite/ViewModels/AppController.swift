import Foundation
import Observation
import SwiftData

/// The top-level coordinator that owns every other view model, wires the SwiftData
/// `ModelContext` into them, performs culling mutations (rating/flag/color label/trash)
/// that don't belong to any single panel, and is the single place keyboard shortcuts get
/// translated into action — see `perform(_:)`.
@MainActor
@Observable
final class AppController {
    let library = LibraryViewModel()
    let editor = EditorViewModel()
    let projects = ProjectsViewModel()
    let export = ExportViewModel()

    private(set) var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        editor.configure(modelContext: modelContext)
        projects.configure(modelContext: modelContext)
    }

    // MARK: - Culling

    func togglePick(_ photo: Photo) {
        photo.flag = photo.flag == .picked ? .none : .picked
        touch(photo)
    }

    func toggleReject(_ photo: Photo) {
        photo.flag = photo.flag == .rejected ? .none : .rejected
        touch(photo)
    }

    func clearFlag(_ photo: Photo) {
        photo.flag = .none
        touch(photo)
    }

    func setRating(_ rating: Int, for photo: Photo) {
        photo.rating = rating
        touch(photo)
    }

    func setColorLabel(_ label: ColorLabelTag, for photo: Photo) {
        photo.colorLabel = label
        touch(photo)
    }

    private func touch(_ photo: Photo) {
        photo.dateModified = .now
        try? modelContext?.save()
        Task { await ThumbnailService.shared.invalidate(photoID: photo.id) }
    }

    // MARK: - Trash (library-only soft delete; never touches the original file on disk)

    func requestDelete(_ photos: [Photo]) {
        guard !photos.isEmpty else { return }
        if SettingsStore.shared.confirmBeforeDelete {
            library.pendingDeleteConfirmation = photos
        } else {
            performDelete(photos)
        }
    }

    func performDelete(_ photos: [Photo]) {
        for photo in photos {
            photo.isTrashed = true
        }
        try? modelContext?.save()
        library.selectedPhotoIDs.subtract(photos.map(\.id))
        library.pendingDeleteConfirmation = nil
    }

    func restoreFromTrash(_ photos: [Photo]) {
        for photo in photos {
            photo.isTrashed = false
        }
        try? modelContext?.save()
    }

    func permanentlyRemoveFromLibrary(_ photos: [Photo]) {
        guard let modelContext else { return }
        for photo in photos {
            modelContext.delete(photo)
        }
        try? modelContext.save()
    }

    // MARK: - Batch operations

    private func batchApply(_ apply: @escaping () -> Void, photoCount: Int) {
        if SettingsStore.shared.confirmBeforeBatchApply && photoCount > 1 {
            library.pendingBatchApplyCount = photoCount
            library.pendingBatchApplyConfirmation = apply
        } else {
            apply()
        }
    }

    func pasteEditsToSelection(_ photos: [Photo], includeCropAndPerspective: Bool) {
        guard let copiedEdit = EditClipboard.shared.copiedEdit, !photos.isEmpty else { return }
        let copiedCrop = EditClipboard.shared.copiedCrop
        let copiedPerspective = EditClipboard.shared.copiedPerspective
        batchApply({ [weak self] in
            for photo in photos {
                if photo.editSettings == nil { photo.editSettings = EditSettings() }
                photo.editSettings?.values = copiedEdit
                if includeCropAndPerspective {
                    if let copiedCrop {
                        if photo.cropSettings == nil { photo.cropSettings = CropSettings() }
                        photo.cropSettings?.values = copiedCrop
                    }
                    if let copiedPerspective {
                        if photo.perspectiveSettings == nil { photo.perspectiveSettings = PerspectiveSettings() }
                        photo.perspectiveSettings?.values = copiedPerspective
                    }
                }
                photo.dateModified = .now
            }
            try? self?.modelContext?.save()
        }, photoCount: photos.count)
    }

    func applyPresetToSelection(_ preset: Preset, photos: [Photo]) {
        guard !photos.isEmpty else { return }
        batchApply({ [weak self] in
            for photo in photos {
                if photo.editSettings == nil { photo.editSettings = EditSettings() }
                photo.editSettings?.values = preset.values
                photo.dateModified = .now
            }
            try? self?.modelContext?.save()
        }, photoCount: photos.count)
    }

    // MARK: - Keyboard shortcut dispatch

    func perform(_ action: ShortcutAction) {
        switch action {
        case .nextPhoto: library.selectNext()
        case .previousPhoto: library.selectPrevious()
        case .togglePick: withActivePhoto(togglePick)
        case .reject: withActivePhoto(toggleReject)
        case .clearFlag: withActivePhoto(clearFlag)
        case .rating0: withActivePhoto { self.setRating(0, for: $0) }
        case .rating1: withActivePhoto { self.setRating(1, for: $0) }
        case .rating2: withActivePhoto { self.setRating(2, for: $0) }
        case .rating3: withActivePhoto { self.setRating(3, for: $0) }
        case .rating4: withActivePhoto { self.setRating(4, for: $0) }
        case .rating5: withActivePhoto { self.setRating(5, for: $0) }
        case .deletePhoto: withActivePhoto { self.requestDelete([$0]) }
        case .exitTool: requestActiveTool(.none)
        case .viewGrid: library.viewMode = .grid
        case .viewLoupe: library.viewMode = .loupe
        case .viewCompare: library.viewMode = .compare
        case .viewBeforeAfter:
            library.viewMode = library.viewMode == .beforeAfter ? .loupe : .beforeAfter
        case .cropTool:
            library.viewMode = .loupe
            requestActiveTool(.crop)
        case .perspectiveTool:
            library.viewMode = .loupe
            requestActiveTool(.perspective)
        case .undo: editor.undoManager.undo()
        case .redo: editor.undoManager.redo()
        case .copyEdits: editor.copyEdits()
        case .pasteEdits: editor.pasteEdits(includeCropAndPerspective: false)
        case .resetEdits: editor.resetAll()
        case .exportSelected: export.isPresented = true
        case .colorLabelNone: withActivePhoto { self.setColorLabel(.none, for: $0) }
        case .colorLabelRed: withActivePhoto { self.setColorLabel(.red, for: $0) }
        case .colorLabelYellow: withActivePhoto { self.setColorLabel(.yellow, for: $0) }
        case .colorLabelGreen: withActivePhoto { self.setColorLabel(.green, for: $0) }
        case .colorLabelBlue: withActivePhoto { self.setColorLabel(.blue, for: $0) }
        case .colorLabelPurple: withActivePhoto { self.setColorLabel(.purple, for: $0) }
        }
    }

    private func withActivePhoto(_ body: (Photo) -> Void) {
        guard let photo = library.activePhoto else { return }
        body(photo)
    }

    // MARK: - Crop / perspective tool transitions

    /// The single entry point for changing `library.activeTool`. Honors the user's
    /// confirm-vs-auto-apply settings and, if there are unconfirmed geometry changes and
    /// `warnBeforeDiscardingGeometryChanges` is on, asks for confirmation before discarding
    /// them — surfaced via `library.pendingGeometryDiscardConfirmation`.
    func requestActiveTool(_ tool: ActiveTool) {
        let currentTool = library.activeTool
        guard currentTool != tool else { return }

        let hasUnconfirmedChanges: Bool
        switch currentTool {
        case .crop: hasUnconfirmedChanges = editor.hasUnconfirmedCropChanges
        case .perspective: hasUnconfirmedChanges = editor.hasUnconfirmedPerspectiveChanges
        case .masks: hasUnconfirmedChanges = false
        case .none: hasUnconfirmedChanges = false
        }

        guard hasUnconfirmedChanges, SettingsStore.shared.warnBeforeDiscardingGeometryChanges else {
            applyActiveTool(tool, exiting: currentTool)
            return
        }

        library.pendingGeometryDiscardConfirmation = LibraryViewModel.PendingGeometryDiscard(
            toolBeingExited: currentTool
        ) { [weak self] in
            self?.applyActiveTool(tool, exiting: currentTool)
        }
    }

    private func applyActiveTool(_ tool: ActiveTool, exiting currentTool: ActiveTool) {
        switch currentTool {
        case .crop: editor.exitCropTool()
        case .perspective: editor.exitPerspectiveTool()
        case .masks: editor.exitMasksTool()
        case .none: break
        }
        library.activeTool = tool
        switch tool {
        case .crop: editor.enterCropTool()
        case .perspective: editor.enterPerspectiveTool()
        case .masks: editor.enterMasksTool()
        case .none: break
        }
        library.pendingGeometryDiscardConfirmation = nil
    }
}
