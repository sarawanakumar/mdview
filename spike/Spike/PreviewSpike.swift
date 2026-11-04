import AppKit
import UniformTypeIdentifiers
import WebKit

// Roadmap 0.3: a locked-down WKWebView showing hard-coded HTML, with one
// image served through the mdview-file:// scheme (ADR 0003, 0005).

enum PreviewSpike {
    static let scheme = "mdview-file"

    /// Blocks every load except our own scheme. Second layer behind the
    /// renderer never emitting remote URLs.
    static let ruleListJSON = """
    [
      {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^mdview-file:"}, "action": {"type": "ignore-previous-rules"}}
    ]
    """

    /// Test page. The script must NOT run; the local image must load;
    /// the remote image must be blocked.
    static let html = """
    <!doctype html>
    <html><head><meta charset="utf-8"><title>spike 0.3</title>
    <meta name="color-scheme" content="light dark">
    <style>
      body { font: -apple-system-body; max-width: 40em; margin: 2em auto; padding: 0 1em; }
      table { border-collapse: collapse; } td, th { border: 1px solid #8888; padding: .3em .6em; }
      pre { overflow-x: auto; background: #8882; padding: .6em; }
    </style></head>
    <body>
      <h1>Spike 0.3</h1>
      <p id="js">script did not run</p>
      <script>document.getElementById('js').textContent = 'SCRIPT RAN';</script>
      <table><tr><th>Left</th><th>Right</th></tr><tr><td>a</td><td>b</td></tr></table>
      <pre><code>let x = 1 // a long line that should scroll sideways inside its own box rather than widen the page at all</code></pre>
      <p>Local image: <img id="local" src="pic.png" alt="local"></p>
      <p>Remote image: <img id="remote" src="https://www.apple.com/favicon.ico" alt="remote"></p>
    </body></html>
    """

    /// Reported by the app's own script after load (runs even with page JS off).
    static let checkScript = """
    JSON.stringify({
      scriptText: document.getElementById('js').textContent,
      local: { width: document.getElementById('local').naturalWidth },
      remote: { width: document.getElementById('remote').naturalWidth }
    })
    """

    /// Shared configuration: page JavaScript off, nothing stored, our
    /// scheme handler, and (unless disabled) the block-remote rule list.
    /// The rule list is looked up first and only compiled if missing.
    @MainActor
    static func makeConfiguration(handler: AssetSchemeHandler, blockRemote: Bool) async throws -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(handler, forURLScheme: scheme)
        if blockRemote {
            guard let store = WKContentRuleListStore.default() else {
                throw URLError(.cannotLoadFromNetwork)
            }
            let id = "mdview-block-remote"
            let rules: WKContentRuleList?
            if let existing = try? await store.contentRuleList(forIdentifier: id) {
                rules = existing
            } else {
                rules = try await store.compileContentRuleList(forIdentifier: id, encodedContentRuleList: ruleListJSON)
            }
            guard let rules else { throw URLError(.cannotLoadFromNetwork) }
            config.userContentController.add(rules)
        }
        return config
    }

    /// Wraps rendered Markdown in a minimal page shell.
    static func page(title: String, body: String) -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>\(title)</title>
        <meta name="color-scheme" content="light dark">
        <style>
          body { font: -apple-system-body; line-height: 1.5; max-width: 46em; margin: 2em auto; padding: 0 1.5em; }
          table { border-collapse: collapse; display: block; overflow-x: auto; }
          td, th { border: 1px solid #8888; padding: .3em .6em; }
          pre { overflow-x: auto; background: #8882; padding: .6em; }
          code { font-family: ui-monospace, monospace; }
        </style></head>
        <body>\(body)</body></html>
        """
    }
}

/// Serves files for mdview-file://bundle/<path> from the app bundle's
/// Resources folder. The real handler (roadmap 3.3) will serve files next
/// to the open document instead.
@MainActor
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    private(set) var served: [String] = []

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url,
              let root = Bundle.main.resourceURL?.standardizedFileURL
        else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        let file = root.appending(path: url.path(percentEncoded: false)).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            served.append("MISSING \(url.absoluteString)")
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        task.didReceive(URLResponse(
            url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil
        ))
        task.didReceive(data)
        task.didFinish()
        served.append("OK \(url.absoluteString) (\(data.count) bytes)")
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
