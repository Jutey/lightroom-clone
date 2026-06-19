import Foundation
import SwiftData

/// Central place that builds the SwiftData `ModelContainer` used by the whole app.
/// The store lives in Application Support so it survives app updates and is never
/// confused with the user's original photo files.
enum PersistenceController {
    static let schema = Schema([
        Project.self,
        Album.self,
        Photo.self,
        EditSettings.self,
        CropSettings.self,
        PerspectiveSettings.self,
        Preset.self,
        EditSnapshot.self,
    ])

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DarkroomLite", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var thumbnailCacheDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("ThumbnailCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let storeURL = appSupportDirectory.appendingPathComponent("DarkroomLite.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(
                for: schema,
                configurations: inMemory ? memoryConfiguration : configuration
            )
        } catch {
            // If the on-disk store can't be opened (e.g. corrupted after a crash),
            // fall back to a fresh in-memory store so the app still launches.
            assertionFailure("Failed to create persistent ModelContainer: \(error)")
            return try! ModelContainer(for: schema, configurations: memoryConfiguration)
        }
    }

    /// Seeds the store with built-in presets the first time the app runs.
    @MainActor
    static func seedBuiltInsIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let existing = try? context.fetch(FetchDescriptor<Preset>(predicate: #Predicate { $0.isBuiltIn == true }))
        if existing?.isEmpty ?? true {
            for preset in Preset.builtInDefaults() {
                context.insert(preset)
            }
            try? context.save()
        }
    }
}
