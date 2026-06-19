import SwiftUI

/// Side-by-side comparison of two photos for culling decisions — distinct from Before/After,
/// which compares one photo's edited vs. original state. The left pane always follows
/// `library.activePhoto`; the right pane follows `library.comparePhotoID` (defaulting to the
/// next photo in the filmstrip). Either pane can be repointed via its picker.
struct CompareView: View {
    @Environment(AppController.self) private var app
    let photos: [Photo]
    let projectFolderBookmark: Data?

    private var leftPhoto: Photo? {
        app.library.activePhoto
    }

    private var rightPhoto: Photo? {
        if let id = app.library.comparePhotoID, let match = photos.first(where: { $0.id == id }) {
            return match
        }
        guard let left = leftPhoto, let index = photos.firstIndex(where: { $0.id == left.id }) else {
            return photos.first
        }
        let nextIndex = index + 1
        return nextIndex < photos.count ? photos[nextIndex] : photos.first
    }

    var body: some View {
        HStack(spacing: 1) {
            pane(title: "A", photo: leftPhoto) { selected in
                app.library.selectOnly(selected)
            }
            Divider()
            pane(title: "B", photo: rightPhoto) { selected in
                app.library.comparePhotoID = selected.id
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private func pane(title: String, photo: Photo?, onPick: @escaping (Photo) -> Void) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let photo {
                    EditedPhotoPreviewView(photo: photo, projectFolderBookmark: projectFolderBookmark)
                } else {
                    Text("No Photo").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.caption.bold())
                    .padding(6)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                    .padding(8)
            }

            Picker("", selection: Binding(
                get: { photo?.id },
                set: { newID in
                    guard let newID, let match = photos.first(where: { $0.id == newID }) else { return }
                    onPick(match)
                }
            )) {
                ForEach(photos) { candidate in
                    Text(candidate.fileName).tag(Optional(candidate.id))
                }
            }
            .labelsHidden()
            .padding(6)
        }
    }
}
