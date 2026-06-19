import Foundation
import Observation

/// In-memory "copy edits / paste edits" clipboard shared across the app, plus the
/// pieces needed for batch-apply to multiple selected photos at once.
@Observable
final class EditClipboard {
    static let shared = EditClipboard()

    private(set) var copiedEdit: EditValues?
    private(set) var copiedCrop: CropValues?
    private(set) var copiedPerspective: PerspectiveValues?
    private(set) var hasContent: Bool = false

    private init() {}

    func copy(edit: EditValues, crop: CropValues, perspective: PerspectiveValues) {
        copiedEdit = edit
        copiedCrop = crop
        copiedPerspective = perspective
        hasContent = true
    }

    func copyEditOnly(_ edit: EditValues) {
        copiedEdit = edit
        copiedCrop = nil
        copiedPerspective = nil
        hasContent = true
    }

    func clear() {
        copiedEdit = nil
        copiedCrop = nil
        copiedPerspective = nil
        hasContent = false
    }
}
