import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("Links (2.11, 4.5)")
struct LinkTests {
    @Test func inlineLink() {
        #expect(render("a [*link*](https://x.y) b\n")
            == "<p>a <a href=\"https://x.y\" title=\"https://x.y\"><em>link</em></a> b</p>\n")
    }

    @Test func referenceLink() {
        #expect(render("[ref][r]\n\n[r]: https://x.y/r\n").contains("<a href=\"https://x.y/r\""))
    }

    @Test func angleAutolink() {
        #expect(render("<https://x.y/a>\n") == "<p><a href=\"https://x.y/a\" title=\"https://x.y/a\">https://x.y/a</a></p>\n")
    }

    @Test(arguments: ["other.md", "other.md#section", "#anchor", "../up/doc.md", "img/a b.png",
                      "mailto:me@x.y", "file:///tmp/x.md", "HTTPS://X.Y"])
    func safeDestinations(_ destination: String) {
        #expect(HTMLVisitor.isSafeDestination(destination))
    }

    @Test(arguments: ["javascript:alert(1)", "JavaScript:alert(1)", " javascript:x", "data:text/html,hi",
                      "vbscript:x", "ftp://x.y"])
    func unsafeDestinationsKeepOnlyTheirText(_ destination: String) {
        #expect(!HTMLVisitor.isSafeDestination(destination))
        #expect(render("[click](\(destination))\n") == "<p>click</p>\n")
    }

    @Test func hrefIsEscaped() {
        #expect(render("[x](https://x.y/?a=1&b=\"2\")\n").contains("href=\"https://x.y/?a=1&amp;b=&quot;2&quot;\""))
    }
}

@Suite("Bare web addresses (2.14)")
struct AutolinkTests {
    private func links(_ text: String) -> [String] {
        Autolinker.segments(in: text).compactMap {
            if case .link(let linkText, _) = $0 { String(linkText) } else { nil }
        }
    }

    @Test func httpsHttpAndWww() {
        #expect(links("see https://a.com/x and http://b.org and www.c.net now") == ["https://a.com/x", "http://b.org", "www.c.net"])
    }

    @Test func wwwGetsHTTP() {
        #expect(Autolinker.segments(in: "www.c.net") == [.link(text: "www.c.net", url: "http://www.c.net")])
    }

    @Test(arguments: [
        ("https://a.com/end.", "https://a.com/end"),
        ("https://a.com/x, more", "https://a.com/x"),
        ("https://a.com?", "https://a.com"),
        ("https://a.com/x!", "https://a.com/x"),
        ("https://a.com/x:", "https://a.com/x"),
        ("https://a.com/q\"", "https://a.com/q"),
        ("https://a.com/q'", "https://a.com/q"),
        ("(https://a.com/b)", "https://a.com/b"),
        ("https://en.wikipedia.org/wiki/Swift_(programming_language)", "https://en.wikipedia.org/wiki/Swift_(programming_language)"),
        ("https://a.com/x&amp;", "https://a.com/x"),
        ("https://a.com/path?q=1&r=2#frag", "https://a.com/path?q=1&r=2#frag"),
        ("https://a.com:8080/p", "https://a.com:8080/p"),
        ("https://a.com<b>", "https://a.com"),
    ])
    func trailingCharacters(_ text: String, _ expected: String) {
        #expect(links(text) == [expected])
    }

    /// The last one: GFM only starts a bare link at the start, after a
    /// space, or after `*`, `_`, `~` or `(`; a quote mark right before it
    /// doesn't count.
    @Test(arguments: ["https://localhost", "www.", "https://", "https://a_b.c_d.com", "xhttps://a.com",
                      "foo@bar.com", "http://.com", "\"https://a.com\""])
    func notLinks(_ text: String) {
        #expect(links(text).isEmpty, "\(text) should not be a link")
    }

    @Test func startsAfterEmphasisMarkersAndBrackets() {
        #expect(links("*https://a.com ~https://c.com (www.d.com") == ["https://a.com", "https://c.com", "www.d.com"])
    }

    @Test func insideEmphasisInADocument() {
        // The parser turns the underscores into emphasis first, so the
        // autolinker sees "www.b.com".
        #expect(render("_www.b.com_\n") == "<p><em><a href=\"http://www.b.com\" title=\"http://www.b.com\">www.b.com</a></em></p>\n")
    }

    @Test func uppercaseScheme() {
        #expect(links("HTTPS://A.COM/X") == ["HTTPS://A.COM/X"])
    }

    @Test func unicodeDomain() {
        #expect(links("visit https://café.fr/menu today") == ["https://café.fr/menu"])
    }

    @Test func renderedAsLinks() {
        #expect(render("Go to https://a.com/x.\n")
            == "<p>Go to <a href=\"https://a.com/x\" title=\"https://a.com/x\">https://a.com/x</a>.</p>\n")
    }

    @Test func notInsideCode() {
        #expect(render("`https://a.com`\n") == "<p><code>https://a.com</code></p>\n")
        #expect(!render("```\nhttps://a.com\n```\n").contains("<a "))
    }

    @Test func notInsideALinksText() {
        #expect(render("[https://shown.com](https://real.com)\n")
            == "<p><a href=\"https://real.com\" title=\"https://real.com\">https://shown.com</a></p>\n")
    }

    @Test func textAroundIsStillEscaped() {
        #expect(render("<b> https://a.com &\n") == "<p>&lt;b&gt; <a href=\"https://a.com\" title=\"https://a.com\">https://a.com</a> &amp;</p>\n")
    }
}
