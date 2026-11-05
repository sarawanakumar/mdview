import AppKit
import MDViewCore
import WebKit

/// Shows a document's rendered preview in a locked-down web view.
///
/// Renders when the window opens and again on `reload()` (after a folder
/// grant; on file changes in M4). Zoom, print and find come in M5.
@MainActor
final class PreviewController: NSViewController, WKNavigationDelegate {
    /// After each render: the folder to offer when the page refers to local
    /// files mdview can't read yet (spec 9.5), or nil when it can read
    /// everything it needs.
    var onFolderAccessNeeded: ((URL?) -> Void)?

    private weak var document: MarkdownDocument?
    private var webView: WKWebView?
    private var page: String?
    /// Our page's navigation, so a spare's blank page finishing doesn't
    /// count as the document being visible.
    private var pageNavigation: WKNavigation?

    override func loadView() {
        view = NSView()
    }

    /// Renders the document off the main thread, then shows it.
    func show(_ document: MarkdownDocument) {
        self.document = document
        render()
    }

    /// Renders and shows the document again, in the same web view.
    func reload() {
        render()
    }

    private func render() {
        guard let document else { return }
        let text = document.text
        let isMarkdown = document.isMarkdown
        let title = document.displayName ?? ""
        let fileURL = document.fileURL
        let configuration = PreviewConfiguration.shared()
        let locateImage = ImageAccess.locator(for: fileURL, grants: FolderAccess.shared.snapshot)

        Task {
            // Markdown goes through renderSafely: a large stack, and a plain
            // text fallback for files nested too deeply to parse (spec 10.4).
            let rendered = isMarkdown
                ? await HTMLRenderer.renderSafely(markdown: text, locateImage: locateImage)
                : RenderedPage(html: await Task.detached { HTMLRenderer.render(plainText: text) }.value, localReferences: [])
            Signposts.signposter.emitEvent("documentRendered")
            onFolderAccessNeeded?(fileURL.flatMap { Self.folderNeeded(for: rendered.localReferences, document: $0) })
            do {
                let config = try await configuration.value
                load(PageShell.page(title: title, body: rendered.html), with: config)
            } catch {
                showError(error)
            }
        }
    }

    /// The folder to suggest if the page refers to local files that aren't
    /// the document itself and aren't in a granted folder.
    private static func folderNeeded(for references: [String], document: URL) -> URL? {
        let documentFile = document.standardizedFileURL
        let unreadable = references
            .compactMap { LocalReferences.resolve($0, relativeTo: document) }
            .filter { $0 != documentFile && !FolderAccess.shared.covers($0) }
        guard !unreadable.isEmpty else { return nil }
        return LocalReferences.suggestedFolder(for: document, needing: unreadable)
    }

    private func load(_ page: String, with config: WKWebViewConfiguration) {
        self.page = page
        if let webView {
            pageNavigation = webView.loadHTMLString(page, baseURL: PageShell.baseURL)
            return
        }
        let webView = PreviewConfiguration.takeWebView(with: config)
        // A brand-new web view is white until its first page loads; keep it
        // hidden until then so dark mode never flashes white. (A spare
        // already shows a blank page in the right colours.)
        if webView.url == nil { webView.isHidden = true }
        webView.frame = view.bounds
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setAccessibilityLabel("Preview")
        view.addSubview(webView)
        self.webView = webView
        pageNavigation = webView.loadHTMLString(page, baseURL: PageShell.baseURL)
    }

    /// Spec 9.8: without the block list, show a message instead of the file.
    private func showError(_ error: any Error) {
        let label = NSTextField(wrappingLabelWithString: error.localizedDescription)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),
        ])
    }

    // MARK: WKNavigationDelegate

    /// Only our own page load is allowed. Clicked links are cancelled for
    /// now; roadmap 3.5 routes them (web links to the browser, and so on).
    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        navigationAction.navigationType == .other ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if navigation == pageNavigation {
            webView.isHidden = false
            Signposts.signposter.emitEvent("documentVisible")
        }
    }

    /// If WebKit's page process dies, show the page again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let page { pageNavigation = webView.loadHTMLString(page, baseURL: PageShell.baseURL) }
    }
}

/// Wraps a rendered body in a complete page.
enum PageShell {
    static let baseURL = URL(string: "\(PreviewConfiguration.scheme)://document/")

    /// preview.css from the app bundle, read once.
    private static let css: String = {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return css
    }()

    static func page(title: String, body: String) -> String {
        // The content security policy is one more layer behind the block
        // list and JavaScript being off: no scripts, no remote anything.
        """
        <!doctype html>
        <html lang="en"><head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(PageSecurity.contentSecurityPolicy)">
        <meta name="color-scheme" content="light dark">
        <title>\(HTMLEscaping.escape(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        \(body)</body></html>
        """
    }
}
