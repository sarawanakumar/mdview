import Foundation

/// Turns the local references a page makes (`RenderedPage.localReferences`)
/// into file locations, and picks which folder to offer the user
/// (spec 9.5).
public enum LocalReferences {
    /// The file a reference points to, relative to the document's file.
    /// Handles percent-encoded and plain paths, `file:` URLs, and drops any
    /// `#fragment` or `?query`. Nil if it can't be made into a file URL.
    public static func resolve(_ reference: String, relativeTo document: URL) -> URL? {
        let folder = document.deletingLastPathComponent()
        var reference = reference.trimmingCharacters(in: .whitespaces)
        if let cut = reference.firstIndex(where: { $0 == "#" || $0 == "?" }) {
            reference = String(reference[..<cut])
        }
        guard !reference.isEmpty else { return nil }

        let url: URL?
        if reference.lowercased().hasPrefix("file:") {
            url = URL(string: reference)
        } else if reference.hasPrefix("/") {
            url = URL(fileURLWithPath: reference.removingPercentEncoding ?? reference)
        } else {
            let path = reference.removingPercentEncoding ?? reference
            url = folder.appending(path: path)
        }
        guard let url, url.isFileURL else { return nil }
        return url.standardizedFileURL
    }

    /// The folder to suggest: the closest one holding the document and
    /// every file it needs. For a document whose images sit in a subfolder,
    /// that's the document's own folder; for `../images/a.png`, the folder
    /// above.
    public static func suggestedFolder(for document: URL, needing files: [URL]) -> URL {
        var common = document.deletingLastPathComponent().standardizedFileURL.pathComponents
        for file in files {
            let parts = file.deletingLastPathComponent().standardizedFileURL.pathComponents
            common = Array(zip(common, parts).prefix { $0 == $1 }.map(\.0))
        }
        guard common.count > 1 else { return URL(fileURLWithPath: "/") }
        return URL(fileURLWithPath: "/" + common.dropFirst().joined(separator: "/"), isDirectory: true)
    }
}
