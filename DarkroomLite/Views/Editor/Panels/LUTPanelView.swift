import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Lets the user import a third-party `.cube` 3D LUT and blend it into the render pipeline
/// as a creative-profile-style color grade, with an intensity slider controlling how
/// strongly it's applied.
struct LUTPanelView: View {
    @Environment(AppController.self) private var app
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let lut = app.editor.edit.lut {
                HStack {
                    Image(systemName: "checkerboard.rectangle")
                        .foregroundStyle(.secondary)
                    Text(lut.displayName)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button {
                        app.editor.removeLUT()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove LUT")
                }

                EditSliderRow(
                    title: "Intensity", value: app.editor.lutIntensityBinding(),
                    range: 0...100, defaultValue: 100, actionName: "LUT Intensity"
                )
            } else {
                Text("No LUT loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(app.editor.edit.lut == nil ? "Import LUT…" : "Replace LUT…") {
                importLUT()
            }

            if let importError {
                Text(importError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
    }

    private func importLUT() {
        let panel = NSOpenPanel()
        if let cubeType = UTType(filenameExtension: "cube") {
            panel.allowedContentTypes = [cubeType]
        }
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a .cube 3D LUT file."

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try app.editor.importLUT(from: url)
                importError = nil
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
