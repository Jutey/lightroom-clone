import SwiftUI

/// RAW-only panel: read-only capture info (from EXIF) plus decode-time adjustments that only
/// make sense for RAW files, since they operate on `CIRAWFilter` before demosaicing rather
/// than on the already-decoded image every other panel works with.
struct RawEditPanelView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        if app.library.activePhoto?.isRaw == true {
            rawEditContent
        } else {
            Text("Only available for RAW files.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }

    private var rawEditContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            captureInfo

            Divider()

            EditSliderRow(
                title: "Raw Exposure", value: app.editor.rawBinding(\.exposure),
                range: -4...4, defaultValue: 0, step: 0.05,
                format: { String(format: "%.2f EV", $0) }, actionName: "Raw Exposure"
            )
            EditSliderRow(
                title: "Raw Boost", value: app.editor.rawBinding(\.boostAmount),
                range: 0...200, defaultValue: 100, actionName: "Raw Boost"
            )

            Divider()

            Toggle(
                "Custom White Balance",
                isOn: app.editor.rawBoolBinding(\.useCustomWhiteBalance, actionName: "Toggle Custom White Balance")
            )
            .toggleStyle(.switch)

            if app.editor.edit.rawAdjustments.useCustomWhiteBalance {
                EditSliderRow(
                    title: "Temperature", value: app.editor.rawBinding(\.temperature),
                    range: 2000...12000, defaultValue: 6500, step: 50,
                    format: { String(format: "%.0fK", $0) }, actionName: "White Balance Temperature"
                )
                EditSliderRow(
                    title: "Tint", value: app.editor.rawBinding(\.tint),
                    range: -150...150, defaultValue: 0, actionName: "White Balance Tint"
                )
            }

            ResetPanelButton(kind: .rawEdit)
        }
        .padding(10)
    }

    @ViewBuilder
    private var captureInfo: some View {
        if let photo = app.library.activePhoto {
            VStack(alignment: .leading, spacing: 3) {
                infoRow("Camera", [photo.cameraMake, photo.cameraModel].compactMap { $0 }.joined(separator: " "))
                if let lens = photo.lensModel { infoRow("Lens", lens) }
                infoRow("Exposure", captureExposureSummary(photo))
                if let date = photo.captureDate { infoRow("Captured", Formatters.captureDate.string(from: date)) }
            }
            .font(.caption2)
        }
    }

    private func captureExposureSummary(_ photo: Photo) -> String {
        var parts: [String] = []
        if let focalLength = photo.focalLength { parts.append("\(Int(focalLength))mm") }
        if let aperture = photo.aperture { parts.append(String(format: "f/%.1f", aperture)) }
        if let shutterSpeed = photo.shutterSpeed { parts.append(shutterSpeed) }
        if let iso = photo.iso { parts.append("ISO \(iso)") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
        }
    }
}
