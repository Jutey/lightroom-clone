import SwiftUI

struct DetailPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
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
}
