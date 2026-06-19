import SwiftUI

/// Single large preview of the active photo, fed by the live, debounced `EditorViewModel`
/// render pipeline so it updates as the user adjusts sliders. The crop/perspective tool
/// overlays draw on top when `library.activeTool` is set.
struct LoupeView: View {
    @Environment(AppController.self) private var app
    let projectFolderBookmark: Data?

    var body: some View {
        ZStack {
            Color.black
            if let photo = app.library.activePhoto {
                Group {
                    if let image = app.editor.previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                .overlay {
                    if app.library.activeTool == .crop {
                        CropToolView()
                    } else if app.library.activeTool == .perspective {
                        PerspectiveToolView()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if app.editor.isRendering {
                        ProgressView()
                            .controlSize(.small)
                            .padding(10)
                    }
                }
                .accessibilityLabel(photo.displayName)
            } else {
                ContentUnavailableLabel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
