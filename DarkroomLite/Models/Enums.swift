import Foundation

/// Pick/reject flag used for culling, mirrors Lightroom's flag states.
enum PickFlag: Int, Codable, CaseIterable {
    case none = 0
    case picked = 1
    case rejected = 2
}

/// Color label tags used for quick visual sorting.
enum ColorLabelTag: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case red = 1
    case yellow = 2
    case green = 3
    case blue = 4
    case purple = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
}

/// Main content view mode for the central viewer.
enum ViewMode: String, CaseIterable, Codable {
    case grid
    case loupe
    case compare
    case beforeAfter
}

/// Which geometry/edit tool is currently active in the center viewer.
enum ActiveTool: String, CaseIterable, Codable {
    case none
    case crop
    case perspective
    case masks
    case spotRemoval
    case whiteBalance
}

/// Identifiers for the collapsible/reorderable panels in the right-hand inspector.
enum EditorPanelKind: String, CaseIterable, Codable, Identifiable {
    case light
    case color
    case toneCurve
    case hsl
    case colorGrading
    case effects
    case detail
    case lens
    case rawEdit
    case lut
    case masks
    case spotRemoval
    case crop
    case presets
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .color: return "Color"
        case .toneCurve: return "Tone Curve"
        case .hsl: return "Color Mixer (HSL)"
        case .colorGrading: return "Color Grading"
        case .effects: return "Effects"
        case .detail: return "Detail"
        case .lens: return "Lens Corrections"
        case .rawEdit: return "Raw Edit"
        case .lut: return "LUT / Profile"
        case .masks: return "Masking"
        case .spotRemoval: return "Spot Removal"
        case .crop: return "Crop & Geometry"
        case .presets: return "Presets"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .light: return "sun.max"
        case .color: return "drop"
        case .toneCurve: return "chart.xyaxis.line"
        case .hsl: return "slider.horizontal.3"
        case .colorGrading: return "circle.hexagongrid"
        case .effects: return "sparkles"
        case .detail: return "viewfinder"
        case .lens: return "camera.aperture"
        case .rawEdit: return "gauge.medium"
        case .lut: return "camera.filters"
        case .masks: return "circle.lefthalf.filled"
        case .spotRemoval: return "bandage"
        case .crop: return "crop"
        case .presets: return "square.stack.3d.up"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// Supported file kinds recognized at import time.
enum SupportedFileType: String, CaseIterable {
    case jpg, jpeg, png, heic, heif
    case raw, cr2, cr3, nef, arw, dng, orf, rw2

    static let standardExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]
    static let rawExtensions: Set<String> = ["raw", "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2"]

    static var allExtensions: Set<String> { standardExtensions.union(rawExtensions) }

    static func isSupported(ext: String) -> Bool {
        allExtensions.contains(ext.lowercased())
    }

    static func isRaw(ext: String) -> Bool {
        rawExtensions.contains(ext.lowercased())
    }
}

/// Sort orders available in the library filter bar.
enum LibrarySortOrder: String, CaseIterable, Codable, Identifiable {
    case captureDateNewest
    case captureDateOldest
    case fileName
    case rating
    case importOrder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .captureDateNewest: return "Capture Date (Newest)"
        case .captureDateOldest: return "Capture Date (Oldest)"
        case .fileName: return "File Name"
        case .rating: return "Rating"
        case .importOrder: return "Import Order"
        }
    }
}
