import Foundation
import Observation

enum AppColorScheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum AccentColorOption: String, Codable, CaseIterable, Identifiable {
    case sage, blue, purple, pink, red, orange, yellow, green, teal, graphite
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum GeometryConfirmBehavior: String, Codable, CaseIterable, Identifiable {
    case manualConfirmOnly
    case autoApplyOnExit
    var id: String { rawValue }
    var label: String {
        switch self {
        case .manualConfirmOnly: return "Only apply when I click Confirm"
        case .autoApplyOnExit: return "Automatically apply when I leave the tool"
        }
    }
}

/// App-wide, persisted user preferences. Backed by `UserDefaults` directly (rather than the
/// `@AppStorage` SwiftUI property wrapper) so the same settings are readable from view models
/// and services, not just SwiftUI views.
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    // Crop behavior
    var applyCropOnConfirm: Bool {
        didSet { defaults.set(applyCropOnConfirm, forKey: Keys.applyCropOnConfirm) }
    }
    var cropAutoApplyBehavior: GeometryConfirmBehavior {
        didSet { defaults.set(cropAutoApplyBehavior.rawValue, forKey: Keys.cropAutoApplyBehavior) }
    }
    var defaultCropGuideOverlay: CropGuideOverlay {
        didSet { defaults.set(defaultCropGuideOverlay.rawValue, forKey: Keys.defaultCropGuideOverlay) }
    }

    // Perspective behavior
    var applyPerspectiveOnConfirm: Bool {
        didSet { defaults.set(applyPerspectiveOnConfirm, forKey: Keys.applyPerspectiveOnConfirm) }
    }
    var perspectiveAutoApplyBehavior: GeometryConfirmBehavior {
        didSet { defaults.set(perspectiveAutoApplyBehavior.rawValue, forKey: Keys.perspectiveAutoApplyBehavior) }
    }

    // Confirmations
    var warnBeforeDiscardingGeometryChanges: Bool {
        didSet { defaults.set(warnBeforeDiscardingGeometryChanges, forKey: Keys.warnBeforeDiscardingGeometryChanges) }
    }
    var confirmBeforeDelete: Bool {
        didSet { defaults.set(confirmBeforeDelete, forKey: Keys.confirmBeforeDelete) }
    }
    var confirmBeforeBatchApply: Bool {
        didSet { defaults.set(confirmBeforeBatchApply, forKey: Keys.confirmBeforeBatchApply) }
    }

    // Export defaults
    var lastExportOptionsData: Data? {
        didSet { defaults.set(lastExportOptionsData, forKey: Keys.lastExportOptionsData) }
    }
    var lastExportDestinationBookmark: Data? {
        didSet { defaults.set(lastExportDestinationBookmark, forKey: Keys.lastExportDestinationBookmark) }
    }
    var rememberLastExportSettings: Bool {
        didSet { defaults.set(rememberLastExportSettings, forKey: Keys.rememberLastExportSettings) }
    }

    // Theme
    var colorScheme: AppColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }
    var accentColor: AccentColorOption {
        didSet { defaults.set(accentColor.rawValue, forKey: Keys.accentColor) }
    }

    // Thumbnail / cache
    var thumbnailMaxPixelSize: Double {
        didSet { defaults.set(thumbnailMaxPixelSize, forKey: Keys.thumbnailMaxPixelSize) }
    }
    var backgroundThumbnailGeneration: Bool {
        didSet { defaults.set(backgroundThumbnailGeneration, forKey: Keys.backgroundThumbnailGeneration) }
    }
    var maxConcurrentThumbnailTasks: Double {
        didSet { defaults.set(maxConcurrentThumbnailTasks, forKey: Keys.maxConcurrentThumbnailTasks) }
    }

    // Metadata / sidecar
    var writeSidecarFiles: Bool {
        didSet { defaults.set(writeSidecarFiles, forKey: Keys.writeSidecarFiles) }
    }
    var readSidecarFilesOnImport: Bool {
        didSet { defaults.set(readSidecarFilesOnImport, forKey: Keys.readSidecarFilesOnImport) }
    }

    // Autosave
    var autosaveDebounceMilliseconds: Double {
        didSet { defaults.set(autosaveDebounceMilliseconds, forKey: Keys.autosaveDebounceMilliseconds) }
    }

    // Performance
    var rawDraftModeForPreview: Bool {
        didSet { defaults.set(rawDraftModeForPreview, forKey: Keys.rawDraftModeForPreview) }
    }
    var maxPreviewDimension: Double {
        didSet { defaults.set(maxPreviewDimension, forKey: Keys.maxPreviewDimension) }
    }

    // Library defaults
    var includeSubfoldersOnImport: Bool {
        didSet { defaults.set(includeSubfoldersOnImport, forKey: Keys.includeSubfoldersOnImport) }
    }

    // Editor panel layout
    var collapsedPanelKinds: Set<String> {
        didSet { defaults.set(Array(collapsedPanelKinds), forKey: Keys.collapsedPanelKinds) }
    }
    var panelOrder: [String] {
        didSet { defaults.set(panelOrder, forKey: Keys.panelOrder) }
    }

    func isPanelCollapsed(_ kind: EditorPanelKind) -> Bool {
        collapsedPanelKinds.contains(kind.rawValue)
    }

    func setPanelCollapsed(_ kind: EditorPanelKind, collapsed: Bool) {
        if collapsed { collapsedPanelKinds.insert(kind.rawValue) }
        else { collapsedPanelKinds.remove(kind.rawValue) }
    }

    var orderedEditorPanels: [EditorPanelKind] {
        let saved = panelOrder.compactMap { EditorPanelKind(rawValue: $0) }
        let missing = EditorPanelKind.allCases.filter { !saved.contains($0) }
        return saved + missing
    }

    func movePanel(_ kind: EditorPanelKind, toIndex destination: Int) {
        var order = orderedEditorPanels
        guard let sourceIndex = order.firstIndex(of: kind) else { return }
        order.remove(at: sourceIndex)
        let clampedDestination = destination.clamped(to: 0...order.count)
        order.insert(kind, at: clampedDestination)
        panelOrder = order.map(\.rawValue)
    }

    private init() {
        applyCropOnConfirm = defaults.object(forKey: Keys.applyCropOnConfirm) as? Bool ?? true
        cropAutoApplyBehavior = GeometryConfirmBehavior(rawValue: defaults.string(forKey: Keys.cropAutoApplyBehavior) ?? "") ?? .manualConfirmOnly
        defaultCropGuideOverlay = CropGuideOverlay(rawValue: defaults.string(forKey: Keys.defaultCropGuideOverlay) ?? "") ?? .thirds

        applyPerspectiveOnConfirm = defaults.object(forKey: Keys.applyPerspectiveOnConfirm) as? Bool ?? true
        perspectiveAutoApplyBehavior = GeometryConfirmBehavior(rawValue: defaults.string(forKey: Keys.perspectiveAutoApplyBehavior) ?? "") ?? .manualConfirmOnly

        warnBeforeDiscardingGeometryChanges = defaults.object(forKey: Keys.warnBeforeDiscardingGeometryChanges) as? Bool ?? true
        confirmBeforeDelete = defaults.object(forKey: Keys.confirmBeforeDelete) as? Bool ?? true
        confirmBeforeBatchApply = defaults.object(forKey: Keys.confirmBeforeBatchApply) as? Bool ?? true

        lastExportOptionsData = defaults.data(forKey: Keys.lastExportOptionsData)
        lastExportDestinationBookmark = defaults.data(forKey: Keys.lastExportDestinationBookmark)
        rememberLastExportSettings = defaults.object(forKey: Keys.rememberLastExportSettings) as? Bool ?? true

        colorScheme = AppColorScheme(rawValue: defaults.string(forKey: Keys.colorScheme) ?? "") ?? .system
        accentColor = AccentColorOption(rawValue: defaults.string(forKey: Keys.accentColor) ?? "") ?? .sage

        thumbnailMaxPixelSize = defaults.object(forKey: Keys.thumbnailMaxPixelSize) as? Double ?? 320
        backgroundThumbnailGeneration = defaults.object(forKey: Keys.backgroundThumbnailGeneration) as? Bool ?? true
        maxConcurrentThumbnailTasks = defaults.object(forKey: Keys.maxConcurrentThumbnailTasks) as? Double ?? 4

        writeSidecarFiles = defaults.object(forKey: Keys.writeSidecarFiles) as? Bool ?? false
        readSidecarFilesOnImport = defaults.object(forKey: Keys.readSidecarFilesOnImport) as? Bool ?? true

        autosaveDebounceMilliseconds = defaults.object(forKey: Keys.autosaveDebounceMilliseconds) as? Double ?? 350

        rawDraftModeForPreview = defaults.object(forKey: Keys.rawDraftModeForPreview) as? Bool ?? true
        maxPreviewDimension = defaults.object(forKey: Keys.maxPreviewDimension) as? Double ?? 2200

        includeSubfoldersOnImport = defaults.object(forKey: Keys.includeSubfoldersOnImport) as? Bool ?? true

        collapsedPanelKinds = Set(defaults.stringArray(forKey: Keys.collapsedPanelKinds) ?? [])
        panelOrder = defaults.stringArray(forKey: Keys.panelOrder) ?? EditorPanelKind.allCases.map(\.rawValue)
    }

    func resetToDefaults() {
        for key in Keys.all { defaults.removeObject(forKey: key) }
        let fresh = SettingsStore()
        applyCropOnConfirm = fresh.applyCropOnConfirm
        cropAutoApplyBehavior = fresh.cropAutoApplyBehavior
        defaultCropGuideOverlay = fresh.defaultCropGuideOverlay
        applyPerspectiveOnConfirm = fresh.applyPerspectiveOnConfirm
        perspectiveAutoApplyBehavior = fresh.perspectiveAutoApplyBehavior
        warnBeforeDiscardingGeometryChanges = fresh.warnBeforeDiscardingGeometryChanges
        confirmBeforeDelete = fresh.confirmBeforeDelete
        confirmBeforeBatchApply = fresh.confirmBeforeBatchApply
        rememberLastExportSettings = fresh.rememberLastExportSettings
        colorScheme = fresh.colorScheme
        accentColor = fresh.accentColor
        thumbnailMaxPixelSize = fresh.thumbnailMaxPixelSize
        backgroundThumbnailGeneration = fresh.backgroundThumbnailGeneration
        maxConcurrentThumbnailTasks = fresh.maxConcurrentThumbnailTasks
        writeSidecarFiles = fresh.writeSidecarFiles
        readSidecarFilesOnImport = fresh.readSidecarFilesOnImport
        autosaveDebounceMilliseconds = fresh.autosaveDebounceMilliseconds
        rawDraftModeForPreview = fresh.rawDraftModeForPreview
        maxPreviewDimension = fresh.maxPreviewDimension
        includeSubfoldersOnImport = fresh.includeSubfoldersOnImport
        collapsedPanelKinds = fresh.collapsedPanelKinds
        panelOrder = fresh.panelOrder
    }

    private enum Keys {
        static let applyCropOnConfirm = "settings.applyCropOnConfirm"
        static let cropAutoApplyBehavior = "settings.cropAutoApplyBehavior"
        static let defaultCropGuideOverlay = "settings.defaultCropGuideOverlay"
        static let applyPerspectiveOnConfirm = "settings.applyPerspectiveOnConfirm"
        static let perspectiveAutoApplyBehavior = "settings.perspectiveAutoApplyBehavior"
        static let warnBeforeDiscardingGeometryChanges = "settings.warnBeforeDiscardingGeometryChanges"
        static let confirmBeforeDelete = "settings.confirmBeforeDelete"
        static let confirmBeforeBatchApply = "settings.confirmBeforeBatchApply"
        static let lastExportOptionsData = "settings.lastExportOptionsData"
        static let lastExportDestinationBookmark = "settings.lastExportDestinationBookmark"
        static let rememberLastExportSettings = "settings.rememberLastExportSettings"
        static let colorScheme = "settings.colorScheme"
        static let accentColor = "settings.accentColor"
        static let thumbnailMaxPixelSize = "settings.thumbnailMaxPixelSize"
        static let backgroundThumbnailGeneration = "settings.backgroundThumbnailGeneration"
        static let maxConcurrentThumbnailTasks = "settings.maxConcurrentThumbnailTasks"
        static let writeSidecarFiles = "settings.writeSidecarFiles"
        static let readSidecarFilesOnImport = "settings.readSidecarFilesOnImport"
        static let autosaveDebounceMilliseconds = "settings.autosaveDebounceMilliseconds"
        static let rawDraftModeForPreview = "settings.rawDraftModeForPreview"
        static let maxPreviewDimension = "settings.maxPreviewDimension"
        static let includeSubfoldersOnImport = "settings.includeSubfoldersOnImport"
        static let collapsedPanelKinds = "settings.collapsedPanelKinds"
        static let panelOrder = "settings.panelOrder"

        static let all: [String] = [
            applyCropOnConfirm, cropAutoApplyBehavior, defaultCropGuideOverlay,
            applyPerspectiveOnConfirm, perspectiveAutoApplyBehavior,
            warnBeforeDiscardingGeometryChanges, confirmBeforeDelete, confirmBeforeBatchApply,
            lastExportOptionsData, lastExportDestinationBookmark, rememberLastExportSettings,
            colorScheme, accentColor, thumbnailMaxPixelSize, backgroundThumbnailGeneration,
            maxConcurrentThumbnailTasks, writeSidecarFiles, readSidecarFilesOnImport,
            autosaveDebounceMilliseconds, rawDraftModeForPreview, maxPreviewDimension,
            includeSubfoldersOnImport, collapsedPanelKinds, panelOrder,
        ]
    }
}
