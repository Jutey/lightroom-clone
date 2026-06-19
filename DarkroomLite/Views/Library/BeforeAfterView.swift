import SwiftUI

/// Before/After comparison for the loupe-active photo, fed by `EditorViewModel.originalImage`
/// (the unedited render) and `previewImage` (the live edited render). `editor.beforeAfterMode`
/// toggles between two classic layouts: side-by-side and a single split view with a
/// draggable divider.
struct BeforeAfterView: View {
    @Environment(AppController.self) private var app
    @State private var splitFraction: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(app.library.activePhoto?.displayName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Picker("", selection: Binding(
                    get: { app.editor.beforeAfterMode },
                    set: { app.editor.beforeAfterMode = $0 }
                )) {
                    Text("Side by Side").tag(false)
                    Text("Split").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(8)

            GeometryReader { geo in
                if app.editor.beforeAfterMode {
                    splitView(size: geo.size)
                } else {
                    HStack(spacing: 1) {
                        previewPane(app.editor.originalImage, label: "Before")
                        previewPane(app.editor.previewImage, label: "After")
                    }
                }
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private func splitView(size: CGSize) -> some View {
        let splitX = size.width * splitFraction
        ZStack(alignment: .topLeading) {
            previewPane(app.editor.previewImage, label: "After")
            previewPane(app.editor.originalImage, label: "Before")
                .mask(
                    HStack(spacing: 0) {
                        Color.white.frame(width: splitX)
                        Color.clear
                    }
                )
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: size.height)
                .position(x: splitX, y: size.height / 2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                splitFraction = min(max(0, value.location.x / size.width), 1)
            }
        )
    }

    @ViewBuilder
    private func previewPane(_ image: NSImage?, label: String) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            Text(label)
                .font(.caption.bold())
                .padding(6)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.white)
                .padding(8)
        }
    }
}
