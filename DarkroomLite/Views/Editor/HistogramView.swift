import SwiftUI

/// Live RGB histogram with shadow/highlight clipping indicators, docked above the edit panel
/// list. Reads `HistogramData` already computed as a side effect of the existing debounced
/// render pass in `EditorViewModel`, so this view itself does no image processing of its own.
struct HistogramView: View {
    @Environment(AppController.self) private var app

    private var data: HistogramData? { app.editor.histogramData }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.opacity(0.25)
                if let data {
                    channelPath(data.red, in: geo.size)
                        .fill(Color.red.opacity(0.65))
                        .blendMode(.plusLighter)
                    channelPath(data.green, in: geo.size)
                        .fill(Color.green.opacity(0.65))
                        .blendMode(.plusLighter)
                    channelPath(data.blue, in: geo.size)
                        .fill(Color.blue.opacity(0.65))
                        .blendMode(.plusLighter)
                }
                clipIndicators
            }
        }
        .frame(height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private func channelPath(_ values: [Float], in size: CGSize) -> Path {
        Path { path in
            guard values.count > 1, size.width > 0, size.height > 0 else { return }
            let stepX = size.width / CGFloat(values.count - 1)
            path.move(to: CGPoint(x: 0, y: size.height))
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - CGFloat(value) * size.height
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }

    @ViewBuilder
    private var clipIndicators: some View {
        HStack {
            clipTriangle(active: (data?.blackClipFraction ?? 0) > 0.001, systemImage: "arrowtriangle.left.fill")
            Spacer()
            clipTriangle(active: (data?.whiteClipFraction ?? 0) > 0.001, systemImage: "arrowtriangle.right.fill")
        }
        .padding(4)
    }

    private func clipTriangle(active: Bool, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(active ? Color.yellow : Color.white.opacity(0.25))
    }
}
