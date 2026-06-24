import SwiftUI
import AppKit

struct GridView: View {
    @Environment(AppController.self) private var app
    let photos: [Photo]
    let projectFolderBookmark: Data?

    private let cellMinWidth: CGFloat = 140
    private let cellMaxWidth: CGFloat = 220
    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16

    @State private var columnCount: Int = 4
    @State private var resizeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                if photos.isEmpty {
                    ContentUnavailableLabel()
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount), spacing: spacing) {
                        ForEach(photos) { photo in
                            PhotoGridCell(
                                photo: photo,
                                isSelected: app.library.selectedPhotoIDs.contains(photo.id),
                                isActive: app.library.activePhoto?.id == photo.id,
                                projectFolderBookmark: projectFolderBookmark
                            )
                            .frame(maxWidth: cellMaxWidth)
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
                    .padding(horizontalPadding)
                }
            }
            .onAppear {
                columnCount = columns(for: geo.size.width)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                resizeTask?.cancel()
                resizeTask = Task {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    guard !Task.isCancelled else { return }
                    columnCount = columns(for: newWidth)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    /// Approximates `GridItem(.adaptive(minimum:maximum:))`'s column count, but computed once
    /// per debounced resize instead of every layout pass — recomputing `.adaptive` on each
    /// frame of a live window resize/fullscreen animation is what caused the multi-second freeze.
    private func columns(for width: CGFloat) -> Int {
        let available = width - horizontalPadding * 2
        guard available > 0 else { return 1 }
        let count = Int((available + spacing) / (cellMinWidth + spacing))
        return max(1, count)
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
