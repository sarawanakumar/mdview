import AppKit
import MDViewCore
import WebKit

/// Shows a document's rendered preview in a locked-down web view.
///
/// Renders when the window opens and again on `reload()` (after a folder
/// grant; on file changes in M4). Zoom, print and find come in M5.
@MainActor
final class PreviewController: NSViewController, WKNavigationDelegate, WKUIDelegate, FindTarget {
    /// After each render: the folder to offer when the page refers to local
    /// files mdview can't read yet (spec 9.5), or nil when it can read
    /// everything it needs.
    var onFolderAccessNeeded: ((URL?) -> Void)?
    /// A clicked link, already decided (spec 4.1–4.4). Same-page anchors
    /// are scrolled by WebKit and don't come here.
    var onLink: ((LinkRoute) -> Void)?

    private weak var document: MarkdownDocument?
    private var webView: WKWebView?
    private var page: String?
    private var baseURL: URL?
    /// Our page's navigation, so a spare's blank page finishing doesn't
    /// count as the document being visible.
    private var pageNavigation: WKNavigation?
    /// An `#anchor` to scroll to once the page has loaded (spec 4.3).
    private var pendingFragment: String?
    /// True once our page has finished loading; later renders swap the body
    /// in place instead of loading a new page (spec 5.2).
    private var hasShownPage = false
    /// Numbers each render, so a slow older render never replaces a newer
    /// one.
    private var renderGeneration = 0

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
        renderGeneration += 1
        let generation = renderGeneration

        Task {
            // Markdown goes through renderSafely: a large stack, and a plain
            // text fallback for files nested too deeply to parse (spec 10.4).
            let rendered = isMarkdown
                ? await HTMLRenderer.renderSafely(markdown: text, locateImage: locateImage)
                : RenderedPage(html: await Task.detached { HTMLRenderer.render(plainText: text) }.value, localReferences: [])
            guard generation == renderGeneration else { return }  // a newer render is on its way
            Signposts.signposter.emitEvent("documentRendered")
            onFolderAccessNeeded?(fileURL.flatMap { Self.folderNeeded(for: rendered.localReferences, document: $0) })
            let page = PageShell.page(title: title, body: rendered.html)
            if hasShownPage, await swapBody(rendered.html, title: title, page: page, generation: generation) {
                return
            }
            do {
                let config = try await configuration.value
                load(page, base: PageShell.baseURL(for: fileURL?.resolvingSymlinksInPath()), with: config)
            } catch {
                showError(error)
            }
        }
    }

    /// Replaces the page's content in place, so the scroll position stays
    /// where it was (spec 5.2; the browser keeps it within the new length).
    /// Uses the app's own script with the HTML passed as an argument; page
    /// JavaScript stays off. Returns false if it couldn't, so the caller
    /// loads the page instead.
    private func swapBody(_ body: String, title: String, page: String, generation: Int) async -> Bool {
        guard let webView, pageNavigation == nil else { return false }
        do {
            _ = try await webView.callAsyncJavaScript(
                "document.body.innerHTML = body; document.title = title;",
                arguments: ["body": body, "title": title], contentWorld: .defaultClient
            )
        } catch {
            return false
        }
        guard generation == renderGeneration else { return true }
        self.page = page
        Signposts.signposter.emitEvent("documentVisible")
        return true
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

    private func load(_ page: String, base: URL?, with config: WKWebViewConfiguration) {
        self.page = page
        self.baseURL = base
        if let webView {
            loadPage(in: webView)
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
        webView.uiDelegate = self
        webView.pageZoom = zoom
        webView.setAccessibilityLabel("Preview")
        view.addSubview(webView)
        self.webView = webView
        loadPage(in: webView)
    }

    private func loadPage(in webView: WKWebView) {
        guard let page else { return }
        pageNavigation = webView.loadHTMLString(page, baseURL: baseURL)
    }

    /// Scrolls to the element with this `id` (a heading anchor), now or
    /// once the page has loaded. Uses the app's own script with the id
    /// passed as an argument, so nothing from the link is run as code.
    func scroll(toFragment fragment: String) {
        guard let webView, !webView.isLoading, pageNavigation == nil else {
            pendingFragment = fragment
            return
        }
        Task {
            _ = try? await webView.callAsyncJavaScript(
                "const target = document.getElementById(id); if (target) { target.scrollIntoView(); }",
                arguments: ["id": fragment], contentWorld: .defaultClient
            )
        }
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

    /// Only our own page load goes through, and same-page `#anchor` jumps.
    /// Every other navigation is cancelled and handed to `onLink`.
    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        // Only a clicked link is ever routed. Anything else is either our own
        // page load (this page's base URL, or a spare's blank page; WebKit
        // can ask more than once per load), which is allowed, or something
        // the page shouldn't do, which is cancelled. With page JavaScript off,
        // nothing on the page can start a load itself.
        guard navigationAction.navigationType == .linkActivated else {
            let isOurs = url.absoluteString == baseURL?.absoluteString
                || url.absoluteString == PageShell.blankBaseURL?.absoluteString
            return isOurs && navigationAction.targetFrame?.isMainFrame != false ? .allow : .cancel
        }
        guard let document = documentFile else { return .cancel }
        let route = LinkRoute.decide(url, document: document)
        if route == .scrollInPage { return .allow }
        onLink?(route)
        return .cancel
    }

    /// Cmd-click and `target="_blank"` links ask for a new web view; treat
    /// them as an ordinary click instead.
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, let document = documentFile {
            let route = LinkRoute.decide(url, document: document)
            if route != .scrollInPage { onLink?(route) }
        }
        return nil
    }

    // MARK: Printing (spec 6.8)

    /// WebKit's own print operation for the page. Its view needs a real
    /// size, or WebKit prints blank pages.
    func printOperation(with info: NSPrintInfo) -> NSPrintOperation? {
        guard let webView else { return nil }
        let operation = webView.printOperation(with: info)
        operation.view?.frame = webView.bounds
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation
    }

    // MARK: Zoom (spec 6.7)

    /// This window's zoom; kept when the page re-renders.
    private(set) var zoom = ZoomLevels.actualSize

    func setZoom(_ zoom: Double) {
        self.zoom = zoom
        webView?.pageZoom = zoom
    }

    // MARK: Find (spec 6.6)

    func find(_ text: String, backwards: Bool) async -> Bool {
        guard let webView else { return false }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        return await withCheckedContinuation { continuation in
            webView.find(text, configuration: configuration) { result in
                continuation.resume(returning: result.matchFound)
            }
        }
    }

    /// Counted with the app's own script; the search text is an argument,
    /// never run as code.
    func countMatches(of text: String) async -> Int {
        guard let webView, !text.isEmpty else { return 0 }
        let script = """
            const haystack = document.body.innerText.toLocaleLowerCase();
            const needle = text.toLocaleLowerCase();
            let count = 0, at = haystack.indexOf(needle);
            while (at !== -1) { count += 1; at = haystack.indexOf(needle, at + needle.length); }
            return count;
            """
        let result = try? await webView.callAsyncJavaScript(script, arguments: ["text": text], contentWorld: .defaultClient)
        return (result as? NSNumber)?.intValue ?? 0
    }

    func clearSelection() async {
        _ = try? await webView?.callAsyncJavaScript("window.getSelection().removeAllRanges();", arguments: [:], contentWorld: .defaultClient)
    }

    func selectedText() async -> String? {
        let result = try? await webView?.callAsyncJavaScript("return window.getSelection().toString();", arguments: [:], contentWorld: .defaultClient)
        return (result as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The document's real path (symlinks resolved, e.g. /tmp → /private/tmp),
    /// matching the page's base URL.
    private var documentFile: URL? {
        document?.fileURL?.resolvingSymlinksInPath()
    }


    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation == pageNavigation else { return }
        pageNavigation = nil
        hasShownPage = true
        webView.isHidden = false
        Signposts.signposter.emitEvent("documentVisible")
        if let fragment = pendingFragment {
            pendingFragment = nil
            scroll(toFragment: fragment)
        }
    }

    /// If WebKit's page process dies, show the page again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadPage(in: webView)
    }
}

/// Wraps a rendered body in a complete page.
enum PageShell {
    /// For a blank page (the spare).
    static let blankBaseURL = URL(string: "\(PreviewConfiguration.scheme)://document/")

    /// `mdview-file://document/<document's folder>/`, so WebKit resolves
    /// relative links (including `../`) into real file paths (spec 4.2).
    static func baseURL(for document: URL?) -> URL? {
        guard let folder = document?.deletingLastPathComponent() else { return blankBaseURL }
        var components = URLComponents()
        components.scheme = PreviewConfiguration.scheme
        components.host = ImageAccess.host
        let path = folder.path(percentEncoded: false)
        components.path = path.hasSuffix("/") ? path : path + "/"
        return components.url ?? blankBaseURL
    }

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
