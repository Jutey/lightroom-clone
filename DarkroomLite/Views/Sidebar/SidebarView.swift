import SwiftUI
import SwiftData

/// Left sidebar: the list of projects (imported folders), each expandable to show its
/// albums, plus the Import Folder button. Selection is plain state on `LibraryViewModel`
/// (not `List(selection:)`, since a row can be either a `Project` or an `Album`).
struct SidebarView: View {
    @Environment(AppController.self) private var app
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var expandedProjectIDs: Set<UUID> = []

    @State private var renamingProject: Project?
    @State private var renamingAlbum: Album?
    @State private var creatingAlbumFor: Project?
    @State private var nameFieldText: String = ""

    var body: some View {
        List {
            Section("Projects") {
                if projects.isEmpty {
                    Text("No projects yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(projects) { project in
                    DisclosureGroup(isExpanded: expandedBinding(for: project)) {
                        ForEach((project.albums ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })) { album in
                            albumRow(album, in: project)
                        }
                        Button {
                            creatingAlbumFor = project
                            nameFieldText = ""
                        } label: {
                            Label("New Album", systemImage: "plus")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 12)
                    } label: {
                        projectRow(project)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            importButton
        }
        .onChange(of: projects, initial: true) { _, newProjects in
            if app.library.selectedProject == nil {
                app.library.selectedProject = newProjects.first
            }
        }
        .alert("Rename Project", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("Name", text: $nameFieldText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let project = renamingProject {
                    app.projects.renameProject(project, to: nameFieldText)
                }
            }
        }
        .alert("Rename Album", isPresented: Binding(
            get: { renamingAlbum != nil },
            set: { if !$0 { renamingAlbum = nil } }
        )) {
            TextField("Name", text: $nameFieldText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let album = renamingAlbum {
                    app.projects.renameAlbum(album, to: nameFieldText)
                }
            }
        }
        .alert("New Album", isPresented: Binding(
            get: { creatingAlbumFor != nil },
            set: { if !$0 { creatingAlbumFor = nil } }
        )) {
            TextField("Album Name", text: $nameFieldText)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if let project = creatingAlbumFor {
                    app.projects.createAlbum(named: nameFieldText, in: project)
                    expandedProjectIDs.insert(project.id)
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            app.projects.importFolder { project in
                if let project {
                    app.library.selectedProject = project
                    app.library.selectedAlbum = nil
                    expandedProjectIDs.insert(project.id)
                }
            }
        } label: {
            Label("Import Folder…", systemImage: "folder.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(app.projects.isImporting)
        .padding(8)
        .background(.bar)
    }

    private func expandedBinding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { expandedProjectIDs.contains(project.id) },
            set: { isExpanded in
                if isExpanded { expandedProjectIDs.insert(project.id) }
                else { expandedProjectIDs.remove(project.id) }
            }
        )
    }

    private func isSelected(_ project: Project) -> Bool {
        app.library.selectedProject?.id == project.id && app.library.selectedAlbum == nil
    }

    private func isSelected(_ album: Album) -> Bool {
        app.library.selectedAlbum?.id == album.id
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack {
            Image(systemName: "folder")
                .foregroundStyle(isSelected(project) ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .fontWeight(isSelected(project) ? .semibold : .regular)
                    .lineLimit(1)
                Text("\(project.photoCount) photos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .listRowBackground(isSelected(project) ? Color.accentColor.opacity(0.18) : Color.clear)
        .onTapGesture {
            app.library.selectedProject = project
            app.library.selectedAlbum = nil
        }
        .contextMenu {
            Button("Rename…") {
                renamingProject = project
                nameFieldText = project.name
            }
            Button("Refresh") { app.projects.refresh(project) }
            Divider()
            Button("Delete Project", role: .destructive) {
                if app.library.selectedProject?.id == project.id {
                    app.library.selectedProject = nil
                    app.library.selectedAlbum = nil
                }
                app.projects.deleteProject(project)
            }
        }
    }

    @ViewBuilder
    private func albumRow(_ album: Album, in project: Project) -> some View {
        HStack {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(isSelected(album) ? Color.accentColor : .secondary)
            Text(album.name)
                .fontWeight(isSelected(album) ? .semibold : .regular)
                .lineLimit(1)
            Spacer()
            Text("\(album.photoCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .padding(.leading, 12)
        .listRowBackground(isSelected(album) ? Color.accentColor.opacity(0.18) : Color.clear)
        .onTapGesture {
            app.library.selectedProject = project
            app.library.selectedAlbum = album
        }
        .contextMenu {
            Button("Rename…") {
                renamingAlbum = album
                nameFieldText = album.name
            }
            Button("Delete Album", role: .destructive) {
                if app.library.selectedAlbum?.id == album.id {
                    app.library.selectedAlbum = nil
                }
                app.projects.deleteAlbum(album)
            }
        }
    }
}
