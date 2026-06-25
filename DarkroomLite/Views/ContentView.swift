import SwiftUI
import SwiftData
import AppKit

/// App root: a sidebar (projects) plus a detail area that itself splits into the workspace
/// and, only in the Edit tab, the edit panel — mirroring Lightroom's Library/Develop split,
/// where the right-hand inspector only exists in Develop. Also hosts the toolbar, the
/// customizable-keyboard-shortcut monitor, and the alerts that are global to the whole
/// window rather than any single panel (delete, batch apply, geometry discard).
struct ContentView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            HSplitView {
                workspace
                    .frame(minWidth: 480, idealWidth: 800, maxWidth: .infinity, maxHeight: .infinity)
                if app.library.viewMode.workspaceTab == .edit {
                    EditorPanelContainerView()
                }
            }
        }
        .toolbar {
            MainToolbarContent()
        }
        .background(KeyEventMonitorView(onKeyDown: handleKeyDown))
        .onChange(of: app.library.activePhoto, initial: true) { _, newPhoto in
            if let newPhoto {
                let folderBookmark = app.library.selectedProject?.folderBookmark
                app.editor.load(photo: newPhoto, projectFolderBookmark: folderBookmark)
                app.editor.prefetchNeighbors(of: newPhoto, in: app.library.displayedPhotos, projectFolderBookmark: folderBookmark)
            } else {
                app.editor.unload()
            }
        }
        .onChange(of: app.library.selectedProject) { _, _ in
            app.requestActiveTool(.none)
            app.library.selectedAlbum = nil
            app.library.selectedPhotoIDs = []
        }
        .sheet(isPresented: exportPresentedBinding) {
            ExportSheetView()
        }
        .alert("Move to Trash", isPresented: pendingDeleteBinding) {
            Button("Cancel", role: .cancel) { app.library.pendingDeleteConfirmation = nil }
            Button("Move to Trash", role: .destructive) {
                if let photos = app.library.pendingDeleteConfirmation {
                    app.performDelete(photos)
                }
            }
        } message: {
            Text("This removes \(app.library.pendingDeleteConfirmation?.count ?? 0) photo(s) from the library. The original file(s) on disk are never modified.")
        }
        .alert("Apply to \(app.library.pendingBatchApplyCount) Photos?", isPresented: pendingBatchApplyBinding) {
            Button("Cancel", role: .cancel) { app.library.pendingBatchApplyConfirmation = nil }
            Button("Apply") {
                app.library.pendingBatchApplyConfirmation?()
                app.library.pendingBatchApplyConfirmation = nil
            }
        } message: {
            Text("This will overwrite any existing edits on all selected photos.")
        }
        .alert("Discard Unsaved Geometry Changes?", isPresented: pendingGeometryDiscardBinding) {
            Button("Cancel", role: .cancel) { app.library.pendingGeometryDiscardConfirmation = nil }
            Button("Discard", role: .destructive) {
                app.library.pendingGeometryDiscardConfirmation?.proceed()
            }
        } message: {
            Text("You have unconfirmed crop or perspective changes that haven't been applied yet.")
        }
    }

    @ViewBuilder
    private var workspace: some View {
        if let project = app.library.selectedProject {
            ProjectWorkspaceView(project: project)
        } else {
            VStack(spacing: 8) {
                Spacer()
                Text("No Project Selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Import a folder to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let action = KeyboardShortcutsStore.shared.action(for: event) else { return false }
        app.perform(action)
        return true
    }

    private var exportPresentedBinding: Binding<Bool> {
        Binding(get: { app.export.isPresented }, set: { app.export.isPresented = $0 })
    }

    private var pendingDeleteBinding: Binding<Bool> {
        Binding(
            get: { app.library.pendingDeleteConfirmation != nil },
            set: { if !$0 { app.library.pendingDeleteConfirmation = nil } }
        )
    }

    private var pendingBatchApplyBinding: Binding<Bool> {
        Binding(
            get: { app.library.pendingBatchApplyConfirmation != nil },
            set: { if !$0 { app.library.pendingBatchApplyConfirmation = nil } }
        )
    }

    private var pendingGeometryDiscardBinding: Binding<Bool> {
        Binding(
            get: { app.library.pendingGeometryDiscardConfirmation != nil },
            set: { if !$0 { app.library.pendingGeometryDiscardConfirmation = nil } }
        )
    }
}
