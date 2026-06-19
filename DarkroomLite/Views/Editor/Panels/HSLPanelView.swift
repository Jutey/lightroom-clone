import SwiftUI

struct HSLPanelView: View {
    @Environment(AppController.self) private var app
    @State private var selectedBand: HSLBandName = .red

    var body: some View {
        VStack(spacing: 10) {
            bandPicker

            EditSliderRow(
                title: "Hue", value: app.editor.hslBinding(selectedBand, \.hue),
                actionName: "HSL \(selectedBand.rawValue.capitalized) Hue"
            )
            EditSliderRow(
                title: "Saturation", value: app.editor.hslBinding(selectedBand, \.saturation),
                actionName: "HSL \(selectedBand.rawValue.capitalized) Saturation"
            )
            EditSliderRow(
                title: "Luminance", value: app.editor.hslBinding(selectedBand, \.luminance),
                actionName: "HSL \(selectedBand.rawValue.capitalized) Luminance"
            )

            ResetPanelButton(kind: .hsl)
        }
        .padding(10)
    }

    private var bandPicker: some View {
        HStack(spacing: 6) {
            ForEach(HSLBandName.allCases) { band in
                Circle()
                    .fill(Color(hue: band.centerHue / 360, saturation: 0.85, brightness: 0.85))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.primary, lineWidth: selectedBand == band ? 2 : 0))
                    .onTapGesture { selectedBand = band }
                    .help(band.rawValue.capitalized)
            }
        }
    }
}
