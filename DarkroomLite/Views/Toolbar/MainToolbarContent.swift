import SwiftUI

/// Toolbar shown above the workspace: import/export, crop & perspective tool toggles, and
/// the Pick/Edit tab switch with its mode-specific sub-picker (Grid/Compare under Pick,
/// Loupe/Before-After under Edit). Search/sort/filter live in `FilterBarView` instead, so
/// they aren't duplicated here.
struct MainToolbarContent: ToolbarContent {
    @Environment(AppController.self) private var app

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                app.projects.importFolder { project in
                    if let project {
                        app.library.selectedProject = project
                        app.library.selectedAlbum = nil
                    }
                }
            } label: {
                Label("Import", systemImage: "folder.badge.plus")
            }
            .disabled(app.projects.isImporting)
            .help("Import a folder of photos as a new project")
        }

        ToolbarItemGroup(placement: .principal) {
            Picker("Tab", selection: workspaceTabBinding) {
                Label("Pick", systemImage: "checkmark.circle").tag(WorkspaceTab.pick)
                Label("Edit", systemImage: "slider.horizontal.3").tag(WorkspaceTab.edit)
            }
            .pickerStyle(.segmented)
            .disabled(app.library.activePhoto == nil)

            switch app.library.viewMode.workspaceTab {
            case .pick:
                Picker("View", selection: viewModeBinding) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
                    Label("Compare", systemImage: "rectangle.split.2x1").tag(ViewMode.compare)
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .disabled(app.library.activePhoto == nil)
            case .edit:
                Picker("View", selection: viewModeBinding) {
                    Label("Loupe", systemImage: "photo").tag(ViewMode.loupe)
                    Label("Before / After", systemImage: "rectangle.lefthalf.filled").tag(ViewMode.beforeAfter)
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .disabled(app.library.activePhoto == nil)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                app.library.viewMode = .loupe
                app.requestActiveTool(app.library.activeTool == .crop ? .none : .crop)
            } label: {
                Label("Crop", systemImage: "crop")
            }
            .help("Crop & Straighten")
            .disabled(app.library.activePhoto == nil)
            .foregroundStyle(app.library.activeTool == .crop ? Color.accentColor : Color.primary)

            Button {
                app.library.viewMode = .loupe
                app.requestActiveTool(app.library.activeTool == .perspective ? .none : .perspective)
            } label: {
                Label("Perspective", systemImage: "rotate.3d")
            }
            .help("Perspective Correction")
            .disabled(app.library.activePhoto == nil)
            .foregroundStyle(app.library.activeTool == .perspective ? Color.accentColor : Color.primary)

            Divider()

            Button {
                app.export.isPresented = true
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .disabled(app.library.displayedPhotos.isEmpty)
            .help("Export Photos…")
        }
    }

    private var viewModeBinding: Binding<ViewMode> {
        Binding(get: { app.library.viewMode }, set: { app.library.viewMode = $0 })
    }

    /// Switching tabs lands on each tab's primary mode (Grid for Pick, Loupe for Edit)
    /// rather than trying to preserve a sub-mode that may not make sense in the other tab.
    private var workspaceTabBinding: Binding<WorkspaceTab> {
        Binding(
            get: { app.library.viewMode.workspaceTab },
            set: { newTab in
                switch newTab {
                case .pick: app.library.viewMode = .grid
                case .edit: app.library.viewMode = .loupe
                }
            }
        )
    }
}
