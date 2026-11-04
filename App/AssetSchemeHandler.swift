import WebKit

/// Serves local files to the page through `mdview-file://` (ADR 0005).
///
/// For now it serves nothing: every request fails. Roadmap 3.3 serves
/// images from next to the open document.
@MainActor
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        task.didFailWithError(URLError(.fileDoesNotExist))
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
