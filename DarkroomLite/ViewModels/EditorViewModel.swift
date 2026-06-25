import Foundation
import Observation
import SwiftData
import CoreImage
import AppKit

/// Drives the live editor: holds the working (in-memory) edit/crop/perspective values for
/// whichever photo is currently active, renders a fast debounced preview as the user drags
/// sliders, and persists changes back into the SwiftData models. Everything here is
/// non-destructive — the original file on disk is only ever opened for reading.
@MainActor
@Observable
final class EditorViewModel {
    private(set) var photo: Photo?
    var edit: EditValues = .identity
    var crop: CropValues = .identity
    var perspective: PerspectiveValues = .identity

    private(set) var previewImage: NSImage?
    private(set) var originalImage: NSImage?
    private(set) var isRendering: Bool = false
    private(set) var histogramData: HistogramData?

    var beforeAfterMode: Bool = false
    var selectedMaskID: LocalAdjustmentMask.ID?
    var selectedSpotID: SpotRemoval.ID?

    let undoManager = UndoManager()

    private var sourceCIImage: CIImage?
    private var sourceRawAdjustments = RawAdjustments()
    private var renderTask: Task<Void, Never>?
    private var rawReloadTask: Task<Void, Never>?
    private var cachedColorCubeKey: String = ""
    private var cachedColorCubeFilter: CIFilter?

    private var cachedLUTBookmarkKey: Data?
    private var cachedLUTFilter: CIFilter?

    private var modelContext: ModelContext?
    private var projectFolderBookmark: Data?

    private var cropEntrySnapshot: CropValues?
    private var perspectiveEntrySnapshot: PerspectiveValues?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(photo: Photo, projectFolderBookmark: Data?) {
        saveImmediately()

        self.photo = photo
        self.projectFolderBookmark = projectFolderBookmark
        edit = photo.editSettings?.values ?? .identity
        crop = photo.cropSettings?.values ?? .identity
        perspective = photo.perspectiveSettings?.values ?? .identity
        selectedMaskID = nil
        selectedSpotID = nil
        undoManager.removeAllActions()

        sourceCIImage = nil
        previewImage = nil
        originalImage = nil
        histogramData = nil

        loadSourceAndRender()
    }

    func unload() {
        saveImmediately()
        photo = nil
        sourceCIImage = nil
        previewImage = nil
        originalImage = nil
        histogramData = nil
    }

    private func loadSourceAndRender() {
        guard let photo else { return }
        let bookmark = photo.bookmarkData
        let folderBookmark = projectFolderBookmark
        let relativePath = photo.relativePath
        let isRaw = photo.isRaw
        let draft = SettingsStore.shared.rawDraftModeForPreview
        let rawAdjustments = edit.rawAdjustments

        if rawAdjustments.isIdentity, let cached = SourceImageCache.shared.image(for: photo.id, draft: draft) {
            sourceCIImage = cached
            sourceRawAdjustments = rawAdjustments
            scheduleRenderAndSave(persist: false)
            return
        }

        Task {
            let image = await Task.detached(priority: .userInitiated) {
                SecurityScopedFileAccess.withResolvedURL(
                    bookmark: bookmark, fallbackFolderBookmark: folderBookmark, relativePath: relativePath
                ) { url in
                    ImageRenderer.loadSourceImage(url: url, isRaw: isRaw, draft: draft, rawAdjustments: rawAdjustments)
                } ?? nil
            }.value
            self.sourceCIImage = image
            self.sourceRawAdjustments = rawAdjustments
            self.scheduleRenderAndSave(persist: false)
            if let image, rawAdjustments.isIdentity {
                SourceImageCache.shared.store(image, for: photo.id, draft: draft)
            }
        }
    }

    /// Speculatively decodes the photos adjacent to `photo` in `photos` so that pressing
    /// next/prev again immediately afterward finds a warm cache instead of decoding from
    /// disk — the main source of perceived lag when cycling through RAW files.
    func prefetchNeighbors(of photo: Photo, in photos: [Photo], projectFolderBookmark: Data?) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        let draft = SettingsStore.shared.rawDraftModeForPreview
        for offset in [1, -1, 2] {
            let neighborIndex = index + offset
            guard photos.indices.contains(neighborIndex) else { continue }
            SourceImageCache.shared.prefetch(photos[neighborIndex], projectFolderBookmark: projectFolderBookmark, draft: draft)
        }
    }

    func scheduleRenderAndSave(persist: Bool = true) {
        if let photo, photo.isRaw, edit.rawAdjustments != sourceRawAdjustments {
            scheduleRawReload(persist: persist)
            return
        }
        renderTask?.cancel()
        let debounceMS = SettingsStore.shared.autosaveDebounceMilliseconds
        let editSnapshot = edit
        let cropSnapshot = crop
        let perspectiveSnapshot = perspective

        renderTask = Task {
            if persist {
                try? await Task.sleep(nanoseconds: UInt64(max(0, debounceMS) * 1_000_000))
                if Task.isCancelled { return }
            }
            await self.renderAndMaybeSave(edit: editSnapshot, crop: cropSnapshot, perspective: perspectiveSnapshot, persist: persist)
        }
    }

    /// RAW-only adjustments are baked in at decode time rather than in the ordinary render
    /// pipeline, so any change to `edit.rawAdjustments` requires re-decoding `sourceCIImage`
    /// from disk before the usual render can run. Routed here transparently from
    /// `scheduleRenderAndSave` so every existing caller (reset, paste, presets, snapshots,
    /// the raw bindings) stays correct without special-casing.
    private func scheduleRawReload(persist: Bool) {
        guard let photo else { return }
        renderTask?.cancel()
        rawReloadTask?.cancel()
        let bookmark = photo.bookmarkData
        let folderBookmark = projectFolderBookmark
        let relativePath = photo.relativePath
        let draft = SettingsStore.shared.rawDraftModeForPreview
        let debounceMS = SettingsStore.shared.autosaveDebounceMilliseconds
        let editSnapshot = edit
        let cropSnapshot = crop
        let perspectiveSnapshot = perspective
        let rawAdjustments = edit.rawAdjustments

        rawReloadTask = Task {
            if persist {
                try? await Task.sleep(nanoseconds: UInt64(max(0, debounceMS) * 1_000_000))
                if Task.isCancelled { return }
            }
            let image = await Task.detached(priority: .userInitiated) {
                SecurityScopedFileAccess.withResolvedURL(
                    bookmark: bookmark, fallbackFolderBookmark: folderBookmark, relativePath: relativePath
                ) { url in
                    ImageRenderer.loadSourceImage(url: url, isRaw: true, draft: draft, rawAdjustments: rawAdjustments)
                } ?? nil
            }.value
            if Task.isCancelled { return }
            if let image {
                self.sourceCIImage = image
                self.sourceRawAdjustments = rawAdjustments
            }
            await self.renderAndMaybeSave(edit: editSnapshot, crop: cropSnapshot, perspective: perspectiveSnapshot, persist: persist)
        }
    }

    private func renderAndMaybeSave(edit: EditValues, crop: CropValues, perspective: PerspectiveValues, persist: Bool) async {
        guard let source = sourceCIImage else { return }
        isRendering = true

        let maxDimension = CGFloat(SettingsStore.shared.maxPreviewDimension)
        let cube = colorCube(for: edit)
        let importedLUT = importedLUTFilter(for: edit)

        let (rendered, histogram): (NSImage?, HistogramData?) = await Task.detached(priority: .userInitiated) {
            let downsampled = ImageRenderer.downsampled(source, maxDimension: maxDimension)
            let final = ImageRenderer.render(
                source: downsampled, edit: edit, crop: crop, perspective: perspective,
                cachedColorCube: cube, cachedImportedLUT: importedLUT
            )
            let histogram = HistogramService.compute(from: final, context: ImageRenderer.sharedContext)
            return (ImageRenderer.renderToNSImage(final), histogram)
        }.value

        if Task.isCancelled { return }
        previewImage = rendered
        histogramData = histogram
        isRendering = false

        if originalImage == nil {
            let original = await Task.detached(priority: .utility) {
                ImageRenderer.renderToNSImage(ImageRenderer.downsampled(source, maxDimension: maxDimension))
            }.value
            originalImage = original
        }

        if persist {
            persistToModel()
        }
    }

    private func colorCube(for edit: EditValues) -> CIFilter? {
        let key = "\(edit.hsl)|\(edit.colorGrading)|\(edit.saturation)|\(edit.vibrance)|\(edit.isBlackAndWhite)"
        if key == cachedColorCubeKey, cachedColorCubeFilter != nil {
            return cachedColorCubeFilter
        }
        let filter = LUTBuilder.colorCubeFilter(for: edit)
        cachedColorCubeKey = key
        cachedColorCubeFilter = filter
        return filter
    }

    private func importedLUTFilter(for edit: EditValues) -> CIFilter? {
        guard let lutRef = edit.lut else {
            cachedLUTBookmarkKey = nil
            cachedLUTFilter = nil
            return nil
        }
        if lutRef.bookmark == cachedLUTBookmarkKey, let cached = cachedLUTFilter {
            return cached
        }
        guard let url = SecurityScopedFileAccess.resolveBookmark(lutRef.bookmark) else { return nil }
        let filter = SecurityScopedFileAccess.withSecurityScopedAccess(to: url) {
            CubeLUTParser.colorCubeFilter(at: url)
        } ?? nil
        cachedLUTBookmarkKey = lutRef.bookmark
        cachedLUTFilter = filter
        return filter
    }

    private func persistToModel() {
        guard let photo else { return }
        if photo.editSettings == nil { photo.editSettings = EditSettings() }
        if photo.cropSettings == nil { photo.cropSettings = CropSettings() }
        if photo.perspectiveSettings == nil { photo.perspectiveSettings = PerspectiveSettings() }
        photo.editSettings?.values = edit
        photo.cropSettings?.values = crop
        photo.perspectiveSettings?.values = perspective
        photo.dateModified = .now
        try? modelContext?.save()

        if SettingsStore.shared.writeSidecarFiles {
            writeSidecar(for: photo)
        }
    }

    func saveImmediately() {
        renderTask?.cancel()
        persistToModel()
    }

    private func writeSidecar(for photo: Photo) {
        let bookmark = photo.bookmarkData
        let folderBookmark = projectFolderBookmark
        let relativePath = photo.relativePath
        Task.detached(priority: .utility) {
            SecurityScopedFileAccess.withResolvedURL(
                bookmark: bookmark, fallbackFolderBookmark: folderBookmark, relativePath: relativePath
            ) { url in
                SidecarService.write(for: photo, fileURL: url)
            }
        }
    }

    // MARK: - Edit actions

    func registerUndo(actionName: String, oldEdit: EditValues, oldCrop: CropValues, oldPerspective: PerspectiveValues) {
        undoManager.registerUndo(withTarget: self) { target in
            let redoEdit = target.edit
            let redoCrop = target.crop
            let redoPerspective = target.perspective
            target.edit = oldEdit
            target.crop = oldCrop
            target.perspective = oldPerspective
            target.scheduleRenderAndSave()
            target.registerUndo(actionName: actionName, oldEdit: redoEdit, oldCrop: redoCrop, oldPerspective: redoPerspective)
        }
        undoManager.setActionName(actionName)
    }

    func resetAll() {
        let old = (edit, crop, perspective)
        edit = .identity
        crop = .identity
        perspective = .identity
        registerUndo(actionName: "Reset All Edits", oldEdit: old.0, oldCrop: old.1, oldPerspective: old.2)
        scheduleRenderAndSave()
    }

    func resetPanel(_ panel: EditorPanelKind) {
        let oldEdit = edit
        switch panel {
        case .light:
            edit.exposure = 0; edit.contrast = 0; edit.highlights = 0
            edit.shadows = 0; edit.whites = 0; edit.blacks = 0
        case .color:
            edit.temperature = 0; edit.tint = 0; edit.saturation = 0
            edit.vibrance = 0; edit.isBlackAndWhite = false
        case .toneCurve:
            edit.toneCurve = EditValues.identityCurve
        case .hsl:
            edit.hsl = [:]
        case .colorGrading:
            edit.colorGrading = ColorGradingValues()
        case .effects:
            edit.texture = 0; edit.clarity = 0; edit.dehaze = 0
            edit.vignetteAmount = 0; edit.vignetteMidpoint = 50; edit.vignetteFeather = 50
            edit.grainAmount = 0; edit.grainSize = 25
        case .detail:
            edit.sharpness = 0; edit.sharpenRadius = 1
            edit.noiseReduction = 0; edit.colorNoiseReduction = 0
        case .lens:
            edit.lens = LensValues()
        case .rawEdit:
            edit.rawAdjustments = RawAdjustments()
        case .lut:
            edit.lut = nil
            cachedLUTBookmarkKey = nil
            cachedLUTFilter = nil
        case .masks:
            edit.localAdjustments = []
            selectedMaskID = nil
        case .spotRemoval:
            edit.spotRemovals = []
            selectedSpotID = nil
        case .crop, .presets, .history:
            break
        }
        registerUndo(actionName: "Reset \(panel.title)", oldEdit: oldEdit, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    func copyEdits() {
        EditClipboard.shared.copy(edit: edit, crop: crop, perspective: perspective)
    }

    func pasteEdits(includeCropAndPerspective: Bool) {
        guard let copiedEdit = EditClipboard.shared.copiedEdit else { return }
        let old = (edit, crop, perspective)
        edit = copiedEdit
        if includeCropAndPerspective {
            if let c = EditClipboard.shared.copiedCrop { crop = c }
            if let p = EditClipboard.shared.copiedPerspective { perspective = p }
        }
        registerUndo(actionName: "Paste Edits", oldEdit: old.0, oldCrop: old.1, oldPerspective: old.2)
        scheduleRenderAndSave()
    }

    func applyPreset(_ preset: Preset) {
        let old = edit
        edit = preset.values
        registerUndo(actionName: "Apply Preset", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    /// Imports a third-party `.cube` LUT as a creative profile. Throws `CubeLUTParser.ParseError`
    /// on malformed/unsupported files so the import UI can show a specific message.
    func importLUT(from url: URL) throws {
        let parsed = try CubeLUTParser.parse(url: url).get()
        guard let bookmark = SecurityScopedFileAccess.makeBookmark(for: url) else {
            throw CubeLUTParser.ParseError.unreadable
        }
        let old = edit
        edit.lut = LUTReference(bookmark: bookmark, displayName: url.lastPathComponent, intensity: 100)
        cachedLUTBookmarkKey = bookmark
        cachedLUTFilter = CubeLUTParser.colorCubeFilter(from: parsed)
        registerUndo(actionName: "Import LUT", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    func removeLUT() {
        guard edit.lut != nil else { return }
        let old = edit
        edit.lut = nil
        cachedLUTBookmarkKey = nil
        cachedLUTFilter = nil
        registerUndo(actionName: "Remove LUT", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    // MARK: - Local adjustment masks

    /// No manual confirm step — masks auto-apply immediately, the same as the crop tool, so
    /// these are intentionally empty (see `enterCropTool`/`exitCropTool` for the contrasting
    /// confirm-on-exit model used by perspective).
    func enterMasksTool() {}
    func exitMasksTool() {}

    @discardableResult
    func addMask(kind: LocalMaskKind) -> UUID {
        let old = edit
        let mask = LocalAdjustmentMask(kind: kind)
        edit.localAdjustments.append(mask)
        registerUndo(actionName: "Add Mask", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
        return mask.id
    }

    func deleteMask(id: LocalAdjustmentMask.ID) {
        guard edit.localAdjustments.contains(where: { $0.id == id }) else { return }
        let old = edit
        edit.localAdjustments.removeAll { $0.id == id }
        registerUndo(actionName: "Delete Mask", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    // MARK: - Spot removal / healing brush

    /// Same auto-apply-immediately model as masks; see `enterMasksTool`/`exitMasksTool`.
    func enterSpotRemovalTool() {}
    func exitSpotRemovalTool() {}

    @discardableResult
    func addSpot() -> UUID {
        let old = edit
        let spot = SpotRemoval()
        edit.spotRemovals.append(spot)
        registerUndo(actionName: "Add Spot Removal", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
        return spot.id
    }

    func deleteSpot(id: SpotRemoval.ID) {
        guard edit.spotRemovals.contains(where: { $0.id == id }) else { return }
        let old = edit
        edit.spotRemovals.removeAll { $0.id == id }
        registerUndo(actionName: "Delete Spot Removal", oldEdit: old, oldCrop: crop, oldPerspective: perspective)
        scheduleRenderAndSave()
    }

    // MARK: - White balance eyedropper

    /// No persistent state of its own — picking just nudges `edit.temperature`/`tint` — so,
    /// like masks/spot removal, there's nothing to set up or tear down on tool switch.
    func enterWhiteBalanceTool() {}
    func exitWhiteBalanceTool() {}

    /// Samples the exact pixel the user tapped in the current rendered preview and nudges
    /// `edit.temperature`/`tint` by whatever delta makes that pixel neutral gray (see
    /// `ImageRenderer.neutralizingWhiteBalanceDelta`). Picking a true neutral gray/white area
    /// gives the best result. The numeric solve re-renders the pipeline and runs a small
    /// bisection search, so it's done off the main thread like any other render; the `edit ==
    /// editSnapshot` guard drops a stale result if the user changed something while it ran.
    func pickWhiteBalance(atNormalizedPoint point: CGPoint) {
        guard let source = sourceCIImage else { return }
        let maxDimension = CGFloat(SettingsStore.shared.maxPreviewDimension)
        let editSnapshot = edit
        let cropSnapshot = crop
        let perspectiveSnapshot = perspective
        let cube = colorCube(for: edit)
        let importedLUT = importedLUTFilter(for: edit)

        Task {
            let delta = await Task.detached(priority: .userInitiated) {
                let downsampled = ImageRenderer.downsampled(source, maxDimension: maxDimension)
                let rendered = ImageRenderer.render(
                    source: downsampled, edit: editSnapshot, crop: cropSnapshot, perspective: perspectiveSnapshot,
                    cachedColorCube: cube, cachedImportedLUT: importedLUT
                )
                return ImageRenderer.neutralizingWhiteBalanceDelta(in: rendered, atNormalizedPoint: point)
            }.value

            guard let delta, self.edit == editSnapshot else { return }
            let old = self.edit
            self.edit.temperature = max(-100, min(100, self.edit.temperature + delta.temperature))
            self.edit.tint = max(-100, min(100, self.edit.tint + delta.tint))
            self.registerUndo(actionName: "White Balance", oldEdit: old, oldCrop: self.crop, oldPerspective: self.perspective)
            self.scheduleRenderAndSave()
        }
    }

    func saveAsPreset(name: String, modelContext: ModelContext) {
        let preset = Preset(name: name, values: edit)
        modelContext.insert(preset)
        try? modelContext.save()
    }

    func saveSnapshot(name: String) {
        guard let photo, let modelContext else { return }
        let snapshot = EditSnapshot(name: name, edit: edit, crop: crop, perspective: perspective)
        snapshot.photo = photo
        modelContext.insert(snapshot)
        try? modelContext.save()
    }

    func restoreSnapshot(_ snapshot: EditSnapshot) {
        let old = (edit, crop, perspective)
        edit = snapshot.edit
        if let c = snapshot.crop { crop = c }
        if let p = snapshot.perspective { perspective = p }
        registerUndo(actionName: "Restore Snapshot", oldEdit: old.0, oldCrop: old.1, oldPerspective: old.2)
        scheduleRenderAndSave()
    }

    // MARK: - Crop / perspective tool confirm-vs-auto-apply

    func enterCropTool() {
        cropEntrySnapshot = crop
    }

    func enterPerspectiveTool() {
        perspectiveEntrySnapshot = perspective
    }

    /// Moves the "confirmed" baseline up to the current values, so leaving the tool afterward
    /// (even in manual-confirm mode) won't revert anything the user already confirmed.
    func confirmCrop() {
        cropEntrySnapshot = crop
    }

    func confirmPerspective() {
        perspectiveEntrySnapshot = perspective
    }

    func cancelPerspectiveTool() {
        if let snapshot = perspectiveEntrySnapshot {
            perspective = snapshot
            scheduleRenderAndSave()
        }
        perspectiveEntrySnapshot = nil
    }

    var hasUnconfirmedCropChanges: Bool {
        guard let cropEntrySnapshot else { return false }
        return cropEntrySnapshot != crop
    }

    var hasUnconfirmedPerspectiveChanges: Bool {
        guard let perspectiveEntrySnapshot else { return false }
        return perspectiveEntrySnapshot != perspective
    }

    /// Called when leaving the crop tool. In manual-confirm mode, reverts to whatever was
    /// confirmed (or the values on entry, if nothing was ever confirmed); in auto-apply mode,
    /// simply keeps whatever the live values currently are.
    func exitCropTool() {
        if SettingsStore.shared.cropAutoApplyBehavior == .manualConfirmOnly,
           let snapshot = cropEntrySnapshot, snapshot != crop {
            crop = snapshot
            scheduleRenderAndSave()
        }
        cropEntrySnapshot = nil
    }

    func exitPerspectiveTool() {
        if SettingsStore.shared.perspectiveAutoApplyBehavior == .manualConfirmOnly,
           let snapshot = perspectiveEntrySnapshot, snapshot != perspective {
            perspective = snapshot
            scheduleRenderAndSave()
        }
        perspectiveEntrySnapshot = nil
    }

    func autoStraighten() {
        guard let source = sourceCIImage else { return }
        Task {
            let angle = await Task.detached(priority: .userInitiated) {
                HorizonDetectionService.detectAngle(in: source)
            }.value
            guard let angle else { return }
            let old = crop
            crop.straightenAngle = max(-45, min(45, angle))
            registerUndo(actionName: "Auto Straighten", oldEdit: edit, oldCrop: old, oldPerspective: perspective)
            confirmCrop()
            scheduleRenderAndSave()
        }
    }
}
