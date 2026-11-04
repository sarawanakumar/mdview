import AppKit
import MDViewCore
import WebKit

/// Shows a document's rendered preview in a locked-down web view.
///
/// Roadmap 1.5: renders once when the window opens. Later tasks add reload
/// (M4), zoom, print and find (M5).
@MainActor
final class PreviewController: NSViewController, WKNavigationDelegate {
    private var webView: WKWebView?
    private var page: String?

    override func loadView() {
        view = NSView()
    }

    /// Renders the document off the main thread, then shows it.
    func show(_ document: MarkdownDocument) {
        let text = document.text
        let isMarkdown = document.isMarkdown
        let title = document.displayName ?? ""
        let configuration = PreviewConfiguration.shared()

        Task {
            let body = await Task.detached {
                isMarkdown ? HTMLRenderer.render(markdown: text) : HTMLRenderer.render(plainText: text)
            }.value
            do {
                let config = try await configuration.value
                load(PageShell.page(title: title, body: body), with: config)
            } catch {
                showError(error)
            }
        }
    }

    private func load(_ page: String, with config: WKWebViewConfiguration) {
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setAccessibilityLabel("Preview")
        view.addSubview(webView)
        self.webView = webView
        self.page = page
        webView.loadHTMLString(page, baseURL: PageShell.baseURL)
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

    /// If WebKit's page process dies, show the page again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let page { webView.loadHTMLString(page, baseURL: PageShell.baseURL) }
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
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src \(PreviewConfiguration.scheme):; style-src 'unsafe-inline'">
        <meta name="color-scheme" content="light dark">
        <title>\(HTMLEscaping.escape(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        \(body)</body></html>
        """
    }
}
