import SwiftUI

/// Lists saved snapshots for the active photo — a named, non-linear complement to the
/// linear undo/redo stack `EditorViewModel.undoManager` already provides — plus quick
/// undo/redo buttons. `UndoManager` has no public API to enumerate its stack for display,
/// so this panel can't show a literal step-by-step history list.
struct HistoryPanelView: View {
    @Environment(AppController.self) private var app
    @State private var isNamingSnapshot = false
    @State private var newSnapshotName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { app.editor.undoManager.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!app.editor.undoManager.canUndo)

                Button { app.editor.undoManager.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!app.editor.undoManager.canRedo)

                Spacer()

                Button("Save Snapshot…") {
                    newSnapshotName = ""
                    isNamingSnapshot = true
                }
                .disabled(app.library.activePhoto == nil)
            }

            if let snapshots = app.library.activePhoto?.snapshots, !snapshots.isEmpty {
                ForEach(snapshots.sorted(by: { $0.dateCreated > $1.dateCreated })) { snapshot in
                    snapshotRow(snapshot)
                }
            } else {
                Text("No snapshots yet").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .alert("Save Snapshot", isPresented: $isNamingSnapshot) {
            TextField("Name", text: $newSnapshotName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard !newSnapshotName.isEmpty else { return }
                app.editor.saveSnapshot(name: newSnapshotName)
            }
        }
    }

    private func snapshotRow(_ snapshot: EditSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.name).font(.caption)
                Text(Formatters.captureDate.string(from: snapshot.dateCreated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { app.editor.restoreSnapshot(snapshot) }
                .buttonStyle(.plain)
                .font(.caption)
            Button {
                app.modelContext?.delete(snapshot)
                try? app.modelContext?.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}
