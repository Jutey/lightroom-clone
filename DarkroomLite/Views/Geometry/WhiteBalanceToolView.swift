import SwiftUI

/// Interactive overlay for the white balance eyedropper. A single tap anywhere on the image
/// samples that pixel's current rendered color; `EditorViewModel.pickWhiteBalance` nudges
/// `edit.temperature`/`tint` by whatever delta makes that exact pixel neutral gray. Pick a
/// true neutral (gray/white) area for the best result. Stays active for repeated picks,
/// mirroring the other geometry tools' "Done" button to exit.
struct WhiteBalanceToolView: View {
    @Environment(AppController.self) private var app

    @State private var lastPick: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedImageRect(containerSize: geo.size, imageSize: app.editor.previewImage?.size ?? geo.size)

            ZStack(alignment: .topLeading) {
                Color.white.opacity(0.001)
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(pickGesture(imageRect: imageRect))

                if let lastPick {
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                        .position(lastPick)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    controlBar
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func pickGesture(imageRect: CGRect) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard imageRect.width > 0, imageRect.height > 0, imageRect.contains(value.location) else { return }
                let normalizedX = max(0, min(1, (value.location.x - imageRect.minX) / imageRect.width))
                let normalizedY = max(0, min(1, 1 - (value.location.y - imageRect.minY) / imageRect.height))
                lastPick = value.location
                app.editor.pickWhiteBalance(atNormalizedPoint: CGPoint(x: normalizedX, y: normalizedY))
            }
    }

    private func fittedImageRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let containerAspect = containerSize.width / containerSize.height
        let imageAspect = imageSize.width / imageSize.height
        var size = containerSize
        if imageAspect > containerAspect {
            size.height = containerSize.width / imageAspect
        } else {
            size.width = containerSize.height * imageAspect
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            Text("Click a neutral gray or white area to set white balance.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())

            Button("Done") {
                app.requestActiveTool(.none)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 12)
        }
    }
}
