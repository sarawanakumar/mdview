import Foundation
import MDViewCore
import UniformTypeIdentifiers
import WebKit

/// Serves local images to the page through `mdview-file://` (ADR 0005,
/// spec section 3). The web view never reads the disk itself.
///
/// URLs look like `mdview-file://document/<absolute file path>`. Only image
/// files inside a folder the user has granted are served; anything else
/// fails, even though the renderer already only links images that pass the
/// same check (`ImageAccess`).
@MainActor
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    /// Tasks WebKit has cancelled; replying to one of those would crash.
    private var stopped: Set<ObjectIdentifier> = []

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, let file = ImageAccess.file(for: url),
              ImageAccess.canShow(file, grants: FolderAccess.shared.snapshot) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let id = ObjectIdentifier(task)
        Task {
            // Read off the main thread; answer WebKit back on it.
            let result = await Task.detached(priority: .userInitiated) {
                Result { try Data(contentsOf: file) }
            }.value
            if stopped.remove(id) != nil { return }
            switch result {
            case .success(let data):
                let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
                task.didReceive(data)
                task.didFinish()
            case .failure(let error):
                task.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        stopped.insert(ObjectIdentifier(task))
    }
}

/// Which local images may be shown, and their `mdview-file:` URLs. Plain
/// values only, so the renderer can use it on its own thread.
enum ImageAccess {
    static let host = "document"

    /// The `ImageLocator` for one document: resolves an image source against
    /// the document, and returns its URL only if it can be shown.
    static func locator(for document: URL?, grants: FolderGrantList) -> ImageLocator {
        { source in
            guard let document, let file = LocalReferences.resolve(source, relativeTo: document),
                  canShow(file, grants: grants) else { return nil }
            return url(for: file, version: modificationVersion(of: file))?.absoluteString
        }
    }

    /// The image file's modification time in milliseconds. Added to the
    /// image's URL, so an image that changed gets a new URL and is fetched
    /// again on the next render, while unchanged ones stay cached (spec 5.5).
    static func modificationVersion(of file: URL) -> String? {
        let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return date.map { String(Int64($0.timeIntervalSince1970 * 1000)) }
    }

    /// An image file that exists, inside a granted folder.
    nonisolated static func canShow(_ file: URL, grants: FolderGrantList) -> Bool {
        guard let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image) else { return false }
        return grants.covers(FolderAccess.path(of: file)) && FileManager.default.isReadableFile(atPath: file.path)
    }

    /// `mdview-file://document/<path>[?v=<version>]`. The scheme handler
    /// only looks at the path.
    static func url(for file: URL, version: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = PreviewConfiguration.scheme
        components.host = host
        components.path = file.path(percentEncoded: false)
        if let version { components.queryItems = [URLQueryItem(name: "v", value: version)] }
        return components.url
    }

    static func file(for url: URL) -> URL? {
        guard url.scheme == PreviewConfiguration.scheme, url.host() == host else { return nil }
        let path = url.path(percentEncoded: false)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }
}
