import SwiftUI

struct PhotoGridCell: View {
    @Environment(AppController.self) private var app
    let photo: Photo
    let isSelected: Bool
    let isActive: Bool
    let projectFolderBookmark: Data?

    var body: some View {
        VStack(spacing: 0) {
            PhotoThumbnailView(photo: photo, projectFolderBookmark: projectFolderBookmark)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if photo.isRaw {
                        Text("RAW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.white)
                            .padding(4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if photo.hasEdits {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.tint)
                            .padding(6)
                    }
                }
            PhotoBadgeOverlay(photo: photo) { app.setRating($0, for: photo) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.6) : .clear), lineWidth: isActive ? 3 : 2)
        )
        .opacity(photo.flag == .rejected ? 0.45 : 1)
        .contextMenu { PhotoContextMenu(photo: photo) }
    }
}

struct PhotoContextMenu: View {
    @Environment(AppController.self) private var app
    let photo: Photo

    var body: some View {
        Button(photo.flag == .picked ? "Remove Pick" : "Pick") { app.togglePick(photo) }
        Button(photo.flag == .rejected ? "Remove Reject" : "Reject") { app.toggleReject(photo) }
        Button("Clear Flag") { app.clearFlag(photo) }
        Divider()
        Menu("Set Rating") {
            ForEach(0...5, id: \.self) { rating in
                Button(rating == 0 ? "None" : String(repeating: "★", count: rating)) {
                    app.setRating(rating, for: photo)
                }
            }
        }
        Menu("Color Label") {
            ForEach(ColorLabelTag.allCases) { label in
                Button(label.displayName) { app.setColorLabel(label, for: photo) }
            }
        }
        Divider()
        Button("Copy Edits") {
            EditClipboard.shared.copy(
                edit: photo.editSettings?.values ?? .identity,
                crop: photo.cropSettings?.values ?? .identity,
                perspective: photo.perspectiveSettings?.values ?? .identity
            )
        }
        Button("Paste Edits") {
            app.pasteEditsToSelection([photo], includeCropAndPerspective: false)
        }
        .disabled(!EditClipboard.shared.hasContent)
        if selectedPhotos.count > 1 {
            Button("Paste Edits to \(selectedPhotos.count) Selected Photos") {
                app.pasteEditsToSelection(selectedPhotos, includeCropAndPerspective: false)
            }
            .disabled(!EditClipboard.shared.hasContent)
            Button("Paste Edits + Crop/Perspective to \(selectedPhotos.count) Selected Photos") {
                app.pasteEditsToSelection(selectedPhotos, includeCropAndPerspective: true)
            }
            .disabled(!EditClipboard.shared.hasContent)
        }
        Divider()
        Button("Move to Trash", role: .destructive) {
            app.requestDelete([photo])
        }
    }

    private var selectedPhotos: [Photo] {
        app.library.selectedPhotos(in: app.library.displayedPhotos)
    }
}
