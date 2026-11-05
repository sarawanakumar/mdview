import MDViewCore
import OSLog
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
    nonisolated static let scheme = PageSecurity.scheme
    private static let log = Logger(subsystem: "com.inferly.mdview", category: "preview")

    private static var loading: Task<WKWebViewConfiguration, any Error>?
    private static let assets = AssetSchemeHandler()

    /// Starts building the configuration (once) and returns the task.
    /// Called at launch so WebKit is ready by the time a file arrives.
    @discardableResult
    static func shared() -> Task<WKWebViewConfiguration, any Error> {
        if let loading { return loading }
        startLookingUpBlockList()
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
        // Blank, in the system's light or dark background, so reusing it
        // never flashes white in dark mode.
        webView.loadHTMLString(
            "<!doctype html><meta name=\"color-scheme\" content=\"light dark\"><style>html{background:Canvas}</style>",
            baseURL: PageShell.blankBaseURL
        )
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
        // Tab and Shift-Tab move through links; Return follows one (spec 6.14).
        config.preferences.tabFocusesLinks = true
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(assets, forURLScheme: scheme)

        let rules = try await blockList()
        config.userContentController.add(rules)
        return config
    }
}

extension PreviewConfiguration {
    /// The block list's lookup starts as soon as launch asks for the
    /// configuration, with WebKit's callback API rather than in a task. A
    /// task wouldn't start until AppKit finishes launching, about 85 ms
    /// later; this way the answer is usually waiting by then (roadmap 7.2).
    private static var blockListResult: Result<WKContentRuleList, any Error>?
    private static var blockListWaiters: [CheckedContinuation<WKContentRuleList, any Error>] = []

    fileprivate static func startLookingUpBlockList() {
        guard let store = WKContentRuleListStore.default() else {
            finishBlockList(nil, error: nil)
            return
        }
        store.lookUpContentRuleList(forIdentifier: PageSecurity.blockListID) { cached, _ in
            Task { @MainActor in
                if let cached {
                    finishBlockList(cached, error: nil)
                    return
                }
                // Only on first launch, or after WebKit drops its cache.
                do {
                    let compiled = try await store.compileContentRuleList(
                        forIdentifier: PageSecurity.blockListID, encodedContentRuleList: PageSecurity.blockList
                    )
                    finishBlockList(compiled, error: nil)
                } catch {
                    finishBlockList(nil, error: error)
                }
            }
        }
    }

    /// Any failure means no page is shown (spec 9.8), with mdview's own
    /// message rather than WebKit's.
    private static func finishBlockList(_ rules: WKContentRuleList?, error: (any Error)?) {
        let result: Result<WKContentRuleList, any Error>
        if let rules {
            result = .success(rules)
        } else {
            log.error("block list unavailable: \(error?.localizedDescription ?? "no store", privacy: .public)")
            result = .failure(PreviewError.blockListUnavailable)
        }
        blockListResult = result
        for waiter in blockListWaiters { waiter.resume(with: result) }
        blockListWaiters = []
    }

    fileprivate static func blockList() async throws -> WKContentRuleList {
        if let blockListResult { return try blockListResult.get() }
        return try await withCheckedThrowingContinuation { blockListWaiters.append($0) }
    }
}

enum PreviewError: LocalizedError {
    case blockListUnavailable

    var errorDescription: String? {
        "MDView couldn’t set up its offline protection, so this file isn’t shown."
    }
}
