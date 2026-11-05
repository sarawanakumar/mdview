import AppKit
import MDViewCore
import OSLog

/// Folders the user has allowed mdview to read, kept across launches
/// (ADR 0005, spec 9.5, 9.6).
///
/// Each grant is saved as a security-scoped bookmark in the app's
/// settings. At launch they're resolved and access is started for the rest
/// of the session, so images and linked files in those folders just work.
/// Which folders count is decided by `FolderGrantList` (MDViewCore).
///
/// Note: an ad hoc signed build can't use bookmarks made by a different
/// build (each build has a new signature), so rebuilding forgets grants.
/// A consistently signed release keeps them.
@MainActor
final class FolderAccess {
    static let shared = FolderAccess()

    /// Posted after a new grant, so open windows can show files they
    /// couldn't before (spec 9.5: "without reopening the file").
    static let didChange = Notification.Name("FolderAccessDidChange")

    private static let defaultsKey = "FolderAccessBookmarks"
    private static let log = Logger(subsystem: "com.inferly.mdview", category: "folder-access")

    private var grants = FolderGrantList()
    /// Bookmark data per granted path, in the same order as `grants`.
    private var bookmarks: [String: Data] = [:]
    /// URLs we've started accessing; kept for the whole session.
    private var accessing: [URL] = []

    /// Resolves the saved grants. Called once at launch.
    func restore() {
        let saved = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Data] ?? []
        var restored = 0
        for data in saved {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &isStale
            ), url.startAccessingSecurityScopedResource() else {
                continue  // Folder gone, or bookmark from another build: drop it.
            }
            accessing.append(url)
            let path = Self.path(of: url)
            // A stale bookmark still works now; save a fresh one.
            let fresh = isStale ? (try? url.bookmarkData(options: [.withSecurityScope])) : nil
            if grants.add(path) { bookmarks[path] = fresh ?? data }
            restored += 1
        }
        save()
        Self.log.info("restored \(restored, privacy: .public) of \(saved.count, privacy: .public) folder grants")
    }

    /// Adds a grant for a folder the user just chose (roadmap 3.2's picker,
    /// which gives the app access to it). Returns false if it was already
    /// covered.
    @discardableResult
    func grant(_ folder: URL) throws -> Bool {
        let path = Self.path(of: folder)
        let before = Set(grants.folders)
        guard grants.add(path) else { return false }

        let data = try folder.bookmarkData(options: [.withSecurityScope])
        if folder.startAccessingSecurityScopedResource() { accessing.append(folder) }
        bookmarks[path] = data
        // Folders inside the new one are no longer needed separately.
        for removed in before.subtracting(grants.folders) { bookmarks[removed] = nil }
        save()
        Self.log.info("granted a folder; \(self.grants.folders.count, privacy: .public) grants in all")
        NotificationCenter.default.post(name: Self.didChange, object: self)
        return true
    }

    /// Whether `url` is in a granted folder.
    func covers(_ url: URL) -> Bool {
        grants.covers(Self.path(of: url))
    }

    /// The current grants as a plain value, safe to use off the main thread
    /// (rendering runs on its own thread).
    var snapshot: FolderGrantList { grants }

    private func save() {
        let ordered = grants.folders.compactMap { bookmarks[$0] }
        UserDefaults.standard.set(ordered, forKey: Self.defaultsKey)
    }

    /// The real path, so "/a/../b" and symlinks compare as the same place.
    nonisolated static func path(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
    }
}
