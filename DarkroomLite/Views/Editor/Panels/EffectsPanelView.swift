import SwiftUI

struct EffectsPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            EditSliderRow(title: "Texture", value: app.editor.binding(\.texture), actionName: "Texture")
            EditSliderRow(title: "Clarity", value: app.editor.binding(\.clarity), actionName: "Clarity")
            EditSliderRow(title: "Dehaze", value: app.editor.binding(\.dehaze), actionName: "Dehaze")

            Divider()

            EditSliderRow(title: "Vignette Amount", value: app.editor.binding(\.vignetteAmount), actionName: "Vignette Amount")
            EditSliderRow(
                title: "Vignette Midpoint", value: app.editor.binding(\.vignetteMidpoint),
                range: 0...100, defaultValue: 50, actionName: "Vignette Midpoint"
            )
            EditSliderRow(
                title: "Vignette Feather", value: app.editor.binding(\.vignetteFeather),
                range: 0...100, defaultValue: 50, actionName: "Vignette Feather"
            )

            Divider()

            EditSliderRow(
                title: "Grain Amount", value: app.editor.binding(\.grainAmount),
                range: 0...100, defaultValue: 0, actionName: "Grain Amount"
            )
            EditSliderRow(
                title: "Grain Size", value: app.editor.binding(\.grainSize),
                range: 0...100, defaultValue: 25, actionName: "Grain Size"
            )

            ResetPanelButton(kind: .effects)
        }
        .padding(10)
    }
}
