import SwiftUI
import AppKit

struct GridView: View {
    @Environment(AppController.self) private var app
    let photos: [Photo]
    let projectFolderBookmark: Data?

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)]

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                ContentUnavailableLabel()
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photos) { photo in
                        PhotoGridCell(
                            photo: photo,
                            isSelected: app.library.selectedPhotoIDs.contains(photo.id),
                            isActive: app.library.activePhoto?.id == photo.id,
                            projectFolderBookmark: projectFolderBookmark
                        )
                        .onTapGesture(count: 2) {
                            app.library.selectOnly(photo)
                            app.library.viewMode = .loupe
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            let flags = NSEvent.modifierFlags
                            if flags.contains(.shift) {
                                app.library.selectRange(to: photo)
                            } else if flags.contains(.command) {
                                app.library.toggleSelection(photo, extend: true)
                            } else {
                                app.library.selectOnly(photo)
                            }
                        })
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct ContentUnavailableLabel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Photos")
                .font(.headline)
            Text("Try adjusting your filters, or import a folder of photos to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
