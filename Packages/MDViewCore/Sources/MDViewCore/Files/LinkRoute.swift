import Foundation

/// What clicking a link should do (spec 4.1–4.4). Pure decision; the app
/// carries it out.
///
/// The page's base URL is `mdview-file://document/<document's folder>/`, so
/// WebKit has already resolved relative links (including `../`) into
/// absolute file paths by the time a click arrives.
public enum LinkRoute: Equatable, Sendable {
    /// A web or mail link: open it in the default app (4.1).
    case external(URL)
    /// Another Markdown file: open it in mdview, then scroll to `fragment`
    /// if there is one (4.2, 4.3).
    case openMarkdown(URL, fragment: String?)
    /// Any other local file: open it in its default app (4.4).
    case openFile(URL)
    /// A `#anchor` on this page: let WebKit scroll to it (4.3).
    case scrollInPage
    /// Anything else (unknown schemes): do nothing.
    case ignore

    /// The extensions mdview opens itself (spec section 1).
    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    public static func decide(_ url: URL, document: URL) -> LinkRoute {
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto":
            return .external(url)
        case PageSecurity.scheme:
            guard url.host() == "document" else { return .ignore }
            return local(path: url.path(percentEncoded: false), fragment: url.fragment(percentEncoded: false), document: document)
        case "file":
            return local(path: url.path(percentEncoded: false), fragment: url.fragment(percentEncoded: false), document: document)
        default:
            return .ignore
        }
    }

    private static func local(path: String, fragment: String?, document: URL) -> LinkRoute {
        let documentFile = document.standardizedFileURL
        let folderPath = documentFile.deletingLastPathComponent().path(percentEncoded: false)
        let fragment = fragment.flatMap { $0.isEmpty ? nil : $0 }

        // The page itself (its folder, which is the base URL) or the document
        // file, with an anchor: scroll within the page.
        let target = URL(fileURLWithPath: path).standardizedFileURL
        let isThisPage = target == documentFile || trimmed(path) == trimmed(folderPath)
        if isThisPage { return fragment == nil ? .ignore : .scrollInPage }

        if markdownExtensions.contains(target.pathExtension.lowercased()) {
            return .openMarkdown(target, fragment: fragment)
        }
        return .openFile(target)
    }

    private static func trimmed(_ path: String) -> String {
        var path = path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
