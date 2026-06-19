import SwiftUI
import SwiftData

@main
struct DarkroomLiteApp: App {
    let container: ModelContainer
    @State private var app = AppController()
    @State private var settings = SettingsStore.shared

    init() {
        container = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(settings.colorScheme.colorScheme)
                .tint(settings.accentColor.color)
                .task {
                    app.configure(modelContext: container.mainContext)
                    PersistenceController.seedBuiltInsIfNeeded(container: container)
                }
        }
        .modelContainer(container)
        .commands {
            AppCommands(app: app)
        }

        Settings {
            SettingsRootView()
                .environment(app)
                .frame(width: 640, height: 480)
        }
        .modelContainer(container)
    }
}
