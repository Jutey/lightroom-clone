import SwiftUI

/// Loads and displays a cached thumbnail for one photo via `ThumbnailService`. Shows a
/// neutral placeholder while the thumbnail is generated so grids/filmstrips of thousands
/// of photos can scroll smoothly without blocking on decode.
struct PhotoThumbnailView: View {
    let photo: Photo
    let projectFolderBookmark: Data?
    var maxPixelSize: CGFloat = 320

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: TaskKey(photoID: photo.id, size: maxPixelSize)) {
            image = await ThumbnailService.shared.thumbnail(
                for: photo, maxPixelSize: maxPixelSize, projectFolderBookmark: projectFolderBookmark
            )
        }
    }

    private struct TaskKey: Equatable {
        let photoID: UUID
        let size: CGFloat
    }
}
