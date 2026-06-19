import SwiftUI

struct LensPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            EditSliderRow(title: "Distortion", value: app.editor.lensBinding(\.distortion), actionName: "Lens Distortion")
            EditSliderRow(title: "Vignette Correction", value: app.editor.lensBinding(\.vignetteCorrection), actionName: "Lens Vignette Correction")

            Toggle(
                "Remove Chromatic Aberration",
                isOn: app.editor.lensBoolBinding(\.removeChromaticAberration, actionName: "Toggle Chromatic Aberration Removal")
            )
            .toggleStyle(.switch)
            .padding(.top, 2)

            ResetPanelButton(kind: .lens)
        }
        .padding(10)
    }
}
