/// The settings that keep the preview offline and script-free (ADR 0003,
/// 0006). Plain values here, applied by the app's web view setup, so the
/// tests exercise exactly what the app uses.
public enum PageSecurity {
    /// The only scheme a page may load from (ADR 0005).
    public static let scheme = "mdview-file"

    /// WebKit content rule list: block every load except `mdview-file:`.
    /// Change `blockListID`'s version whenever this changes, so a stale
    /// compiled copy is never reused.
    public static let blockList = """
        [
          {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
          {"trigger": {"url-filter": "^mdview-file:"}, "action": {"type": "ignore-previous-rules"}}
        ]
        """
    public static let blockListID = "mdview-block-remote-v1"

    /// The page's Content Security Policy: nothing by default, images only
    /// from `mdview-file:`, inline styles only. No scripts, no remote
    /// anything, even if the block list were missing.
    public static let contentSecurityPolicy =
        "default-src 'none'; img-src \(scheme):; style-src 'unsafe-inline'"
}
