import SwiftUI

struct DetailPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            detailZoomPreview

            EditSliderRow(
                title: "Sharpness", value: app.editor.binding(\.sharpness),
                range: 0...100, defaultValue: 0, actionName: "Sharpness"
            )
            EditSliderRow(
                title: "Sharpen Radius", value: app.editor.binding(\.sharpenRadius),
                range: 0.5...3, defaultValue: 1, step: 0.1,
                format: { String(format: "%.1f", $0) }, actionName: "Sharpen Radius"
            )

            Divider()

            EditSliderRow(
                title: "Noise Reduction", value: app.editor.binding(\.noiseReduction),
                range: 0...100, defaultValue: 0, actionName: "Noise Reduction"
            )
            EditSliderRow(
                title: "Color Noise Reduction", value: app.editor.binding(\.colorNoiseReduction),
                range: 0...100, defaultValue: 0, actionName: "Color Noise Reduction"
            )

            ResetPanelButton(kind: .detail)
        }
        .padding(10)
    }

    /// A 100% (1:1 pixel) crop from the photo's full resolution, distinct from the main
    /// Loupe preview which is downsampled for interactive performance. Sharpening and noise
    /// reduction act on fine pixel-level grain that downsampling smooths away, so this is the
    /// only place in the editor where those sliders show a visible, true-resolution effect.
    private var detailZoomPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.black.opacity(0.3))
            if let image = app.editor.detailZoomImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(height: 160)
        .overlay(alignment: .topLeading) {
            Text("100% Preview")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(6)
        }
    }
}
