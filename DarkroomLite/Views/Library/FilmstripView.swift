import SwiftUI

/// Horizontal scrolling strip of thumbnails shown beneath the Loupe/Compare/Before-After
/// viewers, so the user can keep browsing and selecting photos without switching back to Grid.
struct FilmstripView: View {
    @Environment(AppController.self) private var app
    let photos: [Photo]
    let projectFolderBookmark: Data?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(photos) { photo in
                        PhotoThumbnailView(photo: photo, projectFolderBookmark: projectFolderBookmark, maxPixelSize: 160)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(
                                        app.library.activePhoto?.id == photo.id ? Color.accentColor : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .opacity(photo.flag == .rejected ? 0.4 : 1)
                            .id(photo.id)
                            .onTapGesture {
                                app.library.selectOnly(photo)
                            }
                    }
                }
                .padding(8)
            }
            .onChange(of: app.library.activePhoto?.id) { _, newID in
                guard let newID else { return }
                withAnimation { proxy.scrollTo(newID, anchor: .center) }
            }
        }
        .frame(height: 80)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
