import SwiftUI

/// Menu-bar commands that mirror the most important keyboard-shortcut actions, so they're
/// discoverable from the menu bar even before a user learns the shortcuts.
struct AppCommands: Commands {
    let app: AppController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import Folder…") {
                app.projects.importFolder { project in
                    if let project {
                        app.library.selectedProject = project
                        app.library.selectedAlbum = nil
                    }
                }
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        CommandGroup(after: .newItem) {
            Button("Export Selected…") {
                app.perform(.exportSelected)
            }
            .keyboardShortcut("e", modifiers: [.command])
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { app.perform(.undo) }
                .keyboardShortcut("z", modifiers: [.command])
            Button("Redo") { app.perform(.redo) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Edits") { app.perform(.copyEdits) }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Paste Edits") { app.perform(.pasteEdits) }
                .keyboardShortcut("v", modifiers: [.command, .option])
            Button("Reset All Edits") { app.perform(.resetEdits) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // Note: the single-letter, no-modifier shortcuts shown in these menu items (g, e, c, \,
        // space, x, u, delete) are handled by the customizable `KeyEventMonitorView` instead of
        // SwiftUI's `.keyboardShortcut`, so they don't hijack keystrokes typed into text fields.
        CommandMenu("View") {
            Button("Grid") { app.perform(.viewGrid) }
            Button("Loupe") { app.perform(.viewLoupe) }
            Button("Compare") { app.perform(.viewCompare) }
            Button("Before / After") { app.perform(.viewBeforeAfter) }
        }

        CommandMenu("Photo") {
            Button("Pick / Favorite") { app.perform(.togglePick) }
            Button("Reject") { app.perform(.reject) }
            Button("Clear Flag") { app.perform(.clearFlag) }
            Divider()
            Button("Move to Trash") { app.perform(.deletePhoto) }
        }
    }
}
