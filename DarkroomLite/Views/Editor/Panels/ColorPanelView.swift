import SwiftUI

struct ColorPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            EditSliderRow(title: "Temperature", value: app.editor.binding(\.temperature), actionName: "Temperature")
            EditSliderRow(title: "Tint", value: app.editor.binding(\.tint), actionName: "Tint")
            EditSliderRow(title: "Saturation", value: app.editor.binding(\.saturation), actionName: "Saturation")
            EditSliderRow(title: "Vibrance", value: app.editor.binding(\.vibrance), actionName: "Vibrance")

            Toggle("Black & White", isOn: app.editor.boolBinding(\.isBlackAndWhite, actionName: "Toggle Black & White"))
                .toggleStyle(.switch)
                .padding(.top, 2)

            ResetPanelButton(kind: .color)
        }
        .padding(10)
    }
}
