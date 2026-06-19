import Foundation

/// Helpers for working with security-scoped bookmarks so the sandboxed app can keep
/// reading user-selected folders/files across app launches without re-prompting.
enum SecurityScopedFileAccess {
    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a bookmark back to a URL. The caller is responsible for calling
    /// `stopAccessingSecurityScopedResource()` on the returned URL when done, paired
    /// with the `startAccessingSecurityScopedResource()` call this performs.
    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url
    }

    /// Runs `body` while holding security-scoped access to `url`, releasing it afterwards.
    @discardableResult
    static func withSecurityScopedAccess<T>(to url: URL, _ body: () throws -> T) rethrows -> T? {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        return try body()
    }

    /// Resolves a photo's bookmark (falling back to its project's folder bookmark + relative
    /// path if the photo itself has no bookmark yet) and runs `body` with scoped access.
    @discardableResult
    static func withResolvedURL<T>(
        bookmark: Data?,
        fallbackFolderBookmark: Data?,
        relativePath: String,
        _ body: (URL) throws -> T
    ) rethrows -> T? {
        if let bookmark, let url = resolveBookmark(bookmark) {
            return try withSecurityScopedAccess(to: url) { try body(url) }
        }
        if let fallbackFolderBookmark, let folderURL = resolveBookmark(fallbackFolderBookmark) {
            return try withSecurityScopedAccess(to: folderURL) {
                let fileURL = folderURL.appendingPathComponent(relativePath)
                return try body(fileURL)
            }
        }
        return nil
    }
}
