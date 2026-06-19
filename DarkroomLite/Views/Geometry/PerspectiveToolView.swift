import SwiftUI

/// Perspective/transform correction overlay: vertical & horizontal perspective, fine
/// rotation, and fill-scale sliders, plus auto-straighten and Confirm/Cancel. Lightroom's
/// full "Guided Upright" (drawing reference lines) is out of scope; these sliders cover the
/// same corrections with direct manual control, which is a reasonable, fully-working
/// substitute.
struct PerspectiveToolView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                sliderRow(
                    "Vertical", value: Binding(
                        get: { app.editor.perspective.verticalPerspective },
                        set: { app.editor.perspective.verticalPerspective = $0; app.editor.scheduleRenderAndSave() }
                    ), range: -100...100
                )
                sliderRow(
                    "Horizontal", value: Binding(
                        get: { app.editor.perspective.horizontalPerspective },
                        set: { app.editor.perspective.horizontalPerspective = $0; app.editor.scheduleRenderAndSave() }
                    ), range: -100...100
                )
                sliderRow(
                    "Rotate", value: Binding(
                        get: { app.editor.perspective.rotation },
                        set: { app.editor.perspective.rotation = $0; app.editor.scheduleRenderAndSave() }
                    ), range: -45...45
                )
                sliderRow(
                    "Scale", value: Binding(
                        get: { app.editor.perspective.scale },
                        set: { app.editor.perspective.scale = $0; app.editor.scheduleRenderAndSave() }
                    ), range: 50...150
                )

                HStack(spacing: 12) {
                    Button("Auto Straighten") { app.editor.autoStraighten() }
                    Button("Reset") {
                        app.editor.perspective = .identity
                        app.editor.scheduleRenderAndSave()
                    }
                    Spacer()
                    Button("Cancel") {
                        app.editor.cancelPerspectiveTool()
                        app.requestActiveTool(.none)
                    }
                    Button("Confirm") {
                        app.editor.confirmPerspective()
                        app.requestActiveTool(.none)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .padding(.bottom, 12)
            .frame(maxWidth: 420)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue))")
                .font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
    }
}
