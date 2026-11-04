import WebKit

/// The web view setup every preview shares (ADR 0003, 0006).
///
/// The app has the outgoing-network entitlement only because WebKit needs
/// it, so this setup is what keeps mdview offline:
/// - page JavaScript is off,
/// - a content rule list blocks every load except `mdview-file:`,
/// - nothing is stored on disk.
/// If the rule list can't be loaded, no page is shown (spec 9.8).
@MainActor
enum PreviewConfiguration {
    nonisolated static let scheme = "mdview-file"

    /// Change the version when `blockList` changes, so a stale compiled
    /// copy is never reused.
    private static let blockListID = "mdview-block-remote-v1"
    private static let blockList = """
    [
      {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^mdview-file:"}, "action": {"type": "ignore-previous-rules"}}
    ]
    """

    private static var loading: Task<WKWebViewConfiguration, any Error>?
    private static let assets = AssetSchemeHandler()

    /// Starts building the configuration (once) and returns the task.
    /// Called at launch so WebKit is ready by the time a file arrives.
    @discardableResult
    static func shared() -> Task<WKWebViewConfiguration, any Error> {
        if let loading { return loading }
        let task = Task {
            let config = try await make()
            Signposts.signposter.emitEvent("previewReady")
            prepareSpare(with: config)
            return config
        }
        loading = task
        return task
    }

    /// One web view with a blank page already loaded, so WebKit's page
    /// process is running before a file arrives (roadmap 1.7). Made at
    /// launch, and again shortly after each one is used, so the next file
    /// opens fast too (spec 8.2). Only ever one: a waiting spare costs about
    /// 9 MB, and memory is the tightest target (spec 8.5).
    private static var spare: WKWebView?

    private static func prepareSpare(with config: WKWebViewConfiguration) {
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString("<!doctype html><title></title>", baseURL: PageShell.baseURL)
        spare = webView
        Signposts.signposter.emitEvent("spareReady")
    }

    /// The spare if there is one, otherwise a new web view.
    static func takeWebView(with config: WKWebViewConfiguration) -> WKWebView {
        if let spare {
            self.spare = nil
            // Wait a moment so the new spare doesn't slow the page being opened.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.spare == nil { prepareSpare(with: config) }
            }
            return spare
        }
        return WKWebView(frame: .zero, configuration: config)
    }

    private static func make() async throws -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(assets, forURLScheme: scheme)

        guard let store = WKContentRuleListStore.default() else {
            throw PreviewError.blockListUnavailable
        }
        let rules: WKContentRuleList?
        if let cached = try? await store.contentRuleList(forIdentifier: blockListID) {
            rules = cached
        } else {
            rules = try await store.compileContentRuleList(
                forIdentifier: blockListID, encodedContentRuleList: blockList
            )
        }
        guard let rules else { throw PreviewError.blockListUnavailable }
        config.userContentController.add(rules)
        return config
    }
}

enum PreviewError: LocalizedError {
    case blockListUnavailable

    var errorDescription: String? {
        "mdview couldn’t set up its offline protection, so this file isn’t shown."
    }
}
