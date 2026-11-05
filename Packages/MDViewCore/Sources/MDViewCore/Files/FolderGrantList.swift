/// The folders the user has allowed mdview to read (ADR 0005, spec 9.5,
/// 9.6), as plain paths. Pure logic, so it can be tested; the app turns
/// these into security-scoped bookmarks (`FolderAccess`).
///
/// A grant covers the folder and everything inside it. Granting a folder
/// that's already covered does nothing; granting a folder above existing
/// grants replaces them.
public struct FolderGrantList: Equatable, Sendable {
    /// Granted folders: absolute, without a trailing "/", none inside
    /// another.
    public private(set) var folders: [String]

    public init(folders: [String] = []) {
        self.folders = []
        for folder in folders { add(folder) }
    }

    /// Whether `path` is a granted folder or inside one.
    public func covers(_ path: String) -> Bool {
        let path = Self.normalized(path)
        return folders.contains { Self.path(path, isInside: $0) }
    }

    /// Adds a grant. Returns false if it was already covered. Grants inside
    /// the new folder are removed, since it now covers them.
    @discardableResult
    public mutating func add(_ folder: String) -> Bool {
        let folder = Self.normalized(folder)
        guard !covers(folder) else { return false }
        folders.removeAll { Self.path($0, isInside: folder) }
        folders.append(folder)
        return true
    }

    // MARK: Paths

    /// Absolute paths, compared as given; "/a/b/" and "/a/b" are the same.
    static func normalized(_ path: String) -> String {
        var path = path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// True if `path` is `folder` or below it. "/a/bc" is not inside "/a/b".
    static func path(_ path: String, isInside folder: String) -> Bool {
        folder == "/" || path == folder || path.hasPrefix(folder + "/")
    }
}
