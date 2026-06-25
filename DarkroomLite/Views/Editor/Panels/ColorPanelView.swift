import SwiftUI

struct ColorPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("White Balance").font(.caption.bold())
                Spacer()
                Button {
                    app.requestActiveTool(app.library.activeTool == .whiteBalance ? .none : .whiteBalance)
                } label: {
                    Label("Pick", systemImage: "eyedropper")
                }
                .buttonStyle(.borderless)
            }
            EditSliderRow(
                title: "Temperature", value: app.editor.binding(\.temperature),
                trackTint: Gradient(colors: [.blue, .yellow]), actionName: "Temperature"
            )
            EditSliderRow(
                title: "Tint", value: app.editor.binding(\.tint),
                trackTint: Gradient(colors: [.green, .pink]), actionName: "Tint"
            )
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
