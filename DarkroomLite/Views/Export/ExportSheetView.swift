import SwiftUI
import AppKit

/// Export sheet: scope picker, format/quality/resize/filename options, and a destination
/// picker that hands off to `ExportService` via `ExportViewModel`. Presented from the
/// toolbar/menu/shortcut by setting `app.export.isPresented = true`.
struct ExportSheetView: View {
    @Environment(AppController.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var exportViewModel: ExportViewModel { app.export }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Photos")
                .font(.title3.bold())

            if exportViewModel.isExporting {
                exportingView
            } else if let result = exportViewModel.lastResult {
                resultView(result)
            } else {
                optionsForm
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { exportViewModel.lastResult = nil }
    }

    private var optionsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker("Export", selection: scopeBinding) {
                    ForEach(ExportSelectionScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }

                Picker("Format", selection: formatBinding) {
                    ForEach(ExportImageFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }

                if exportViewModel.options.format == .jpeg {
                    VStack(alignment: .leading) {
                        Slider(value: qualityBinding, in: 0.1...1, step: 0.05)
                        Text("Quality: \(Int(exportViewModel.options.jpegQuality * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Resize Long Edge", isOn: resizeBinding)
                if exportViewModel.options.resizeLongEdge {
                    TextField("Pixels", value: longEdgeBinding, format: .number)
                        .frame(width: 80)
                }

                Toggle("Add Filename Suffix", isOn: suffixToggleBinding)
                if exportViewModel.options.addSuffixToFilename {
                    TextField("Suffix", text: suffixTextBinding)
                }
            }

            Text("\(photoCount) photo(s) will be exported. The original file(s) are never modified.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Choose Destination…") {
                    exportViewModel.chooseDestinationAndExport(
                        photos: photosToExport,
                        projectFolderBookmark: app.library.selectedProject?.folderBookmark
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(photoCount == 0)
            }
        }
    }

    private var exportingView: some View {
        VStack(spacing: 10) {
            ProgressView(
                value: Double(exportViewModel.progressCurrent),
                total: Double(max(exportViewModel.progressTotal, 1))
            )
            Text("Exporting \(exportViewModel.progressCurrent) of \(exportViewModel.progressTotal)…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultView(_ result: ExportResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Exported \(result.succeeded) photo(s)", systemImage: "checkmark.circle")
                .foregroundStyle(.green)

            if !result.failed.isEmpty {
                Text("\(result.failed.count) failed:")
                    .font(.caption.bold())
                ForEach(result.failed, id: \.fileName) { failure in
                    Text("\(failure.fileName): \(failure.error.localizedDescription)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let destination = exportViewModel.lastDestination {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    exportViewModel.lastResult = nil
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var photosToExport: [Photo] {
        let all = app.library.displayedPhotos
        let selected = app.library.selectedPhotos(in: all)
        return exportViewModel.photosToExport(allPhotos: all, selected: selected)
    }

    private var photoCount: Int { photosToExport.count }

    private var scopeBinding: Binding<ExportSelectionScope> {
        Binding(get: { exportViewModel.scope }, set: { exportViewModel.scope = $0 })
    }

    private var formatBinding: Binding<ExportImageFormat> {
        Binding(get: { exportViewModel.options.format }, set: { exportViewModel.options.format = $0 })
    }

    private var qualityBinding: Binding<Double> {
        Binding(get: { exportViewModel.options.jpegQuality }, set: { exportViewModel.options.jpegQuality = $0 })
    }

    private var resizeBinding: Binding<Bool> {
        Binding(get: { exportViewModel.options.resizeLongEdge }, set: { exportViewModel.options.resizeLongEdge = $0 })
    }

    private var longEdgeBinding: Binding<Int> {
        Binding(get: { exportViewModel.options.longEdgePixels }, set: { exportViewModel.options.longEdgePixels = $0 })
    }

    private var suffixToggleBinding: Binding<Bool> {
        Binding(
            get: { exportViewModel.options.addSuffixToFilename },
            set: { exportViewModel.options.addSuffixToFilename = $0 }
        )
    }

    private var suffixTextBinding: Binding<String> {
        Binding(get: { exportViewModel.options.filenameSuffix }, set: { exportViewModel.options.filenameSuffix = $0 })
    }
}
