import SwiftUI

/// Renders one photo through the full non-destructive edit pipeline (or, with
/// `showOriginal`, with every edit skipped) at a moderate preview resolution. Unlike the
/// live Loupe editor — which only tracks one "active" photo at a time — Compare needs to
/// render two different photos at once, so this does its own one-shot render straight from
/// each photo's saved `EditValues`/`CropValues`/`PerspectiveValues`.
struct EditedPhotoPreviewView: View {
    let photo: Photo
    let projectFolderBookmark: Data?
    var showOriginal: Bool = false
    var maxDimension: CGFloat = 1600

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.black
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
        }
        .task(id: TaskKey(photoID: photo.id, original: showOriginal)) {
            image = await render()
        }
    }

    private struct TaskKey: Equatable {
        let photoID: UUID
        let original: Bool
    }

    private func render() async -> NSImage? {
        let bookmark = photo.bookmarkData
        let folderBookmark = projectFolderBookmark
        let relativePath = photo.relativePath
        let isRaw = photo.isRaw
        let edit: EditValues = showOriginal ? .identity : (photo.editSettings?.values ?? .identity)
        let crop: CropValues = showOriginal ? .identity : (photo.cropSettings?.values ?? .identity)
        let perspective: PerspectiveValues = showOriginal ? .identity : (photo.perspectiveSettings?.values ?? .identity)
        let dimension = maxDimension

        return await Task.detached(priority: .userInitiated) {
            SecurityScopedFileAccess.withResolvedURL(
                bookmark: bookmark, fallbackFolderBookmark: folderBookmark, relativePath: relativePath
            ) { url -> NSImage? in
                guard let source = ImageRenderer.loadSourceImage(url: url, isRaw: isRaw, draft: false, rawAdjustments: edit.rawAdjustments) else { return nil }
                let downsampled = ImageRenderer.downsampled(source, maxDimension: dimension)
                let rendered = ImageRenderer.render(source: downsampled, edit: edit, crop: crop, perspective: perspective)
                return ImageRenderer.renderToNSImage(rendered)
            } ?? nil
        }.value
    }
}
