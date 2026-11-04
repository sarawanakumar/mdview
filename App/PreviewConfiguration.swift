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
        let task = Task { try await make() }
        loading = task
        return task
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
