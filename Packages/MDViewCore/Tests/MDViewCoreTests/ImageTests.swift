import Testing
@testable import MDViewCore

@Suite("Images (spec section 3)")
struct ImageTests {
    /// A pretend app: images under "ok/" exist, everything else doesn't.
    private let locate: ImageLocator = { source in
        source.hasPrefix("ok/") ? "mdview-file://document/notes/\(source)" : nil
    }

    private func render(_ markdown: String) -> String {
        HTMLRenderer.render(markdown: markdown, locateImage: locate)
    }

    @Test func availableLocalImageBecomesImg() {
        #expect(render("![A cat](ok/cat.png)\n")
            == "<p><img src=\"mdview-file://document/notes/ok/cat.png\" alt=\"A cat\" decoding=\"async\"></p>\n")
    }

    @Test func titleIsKept() {
        #expect(render("![A](ok/a.png \"The title\")\n").contains("title=\"The title\""))
    }

    @Test func altTextIsPlainTextOfFormatting() {
        #expect(render("![a *b* `c`](ok/a.png)\n").contains("alt=\"a b c\""))
    }

    @Test func missingImageShowsItsAltText() {
        #expect(render("![A dog](missing/dog.png)\n")
            == "<p><span class=\"image-placeholder\" role=\"img\" aria-label=\"A dog\" title=\"missing/dog.png\">A dog</span></p>\n")
    }

    @Test func remoteImageIsNeverLoaded() {
        let html = render("![Remote](https://example.com/r.png)\n")
        #expect(!html.contains("<img"))
        #expect(html.contains("class=\"image-placeholder\""))
        #expect(html.contains(">Remote</span>"))
    }

    @Test(arguments: ["javascript:alert(1)", "data:image/png;base64,AAAA", "http://x.y/a.png", "//x.y/a.png"])
    func nonLocalSourcesAreNeverImg(_ source: String) {
        #expect(!render("![x](\(source))\n").contains("<img"))
    }

    @Test func noAltTextUsesTheFileName() {
        #expect(render("![](missing/photo.jpg)\n").contains(">photo.jpg</span>"))
    }

    @Test func withoutALocatorEveryImageIsAPlaceholder() {
        #expect(!HTMLRenderer.render(markdown: "![a](ok/a.png)\n").contains("<img"))
    }

    @Test func altAndSourceAreEscaped() {
        let html = render("![\"><script>](missing/a\"b.png)\n")
        #expect(!html.contains("<script"))
        #expect(html.contains("&quot;&gt;&lt;script&gt;"))
    }

    @Test func imageInsideALink() {
        #expect(render("[![logo](ok/l.png)](https://x.y)\n")
            == "<p><a href=\"https://x.y\" title=\"https://x.y\"><img src=\"mdview-file://document/notes/ok/l.png\" alt=\"logo\" decoding=\"async\"></a></p>\n")
    }

    @Test func locatorIsAskedWithTheSourceAsWritten() {
        nonisolated(unsafe) var asked: [String] = []
        _ = HTMLRenderer.render(markdown: "![a](../up/a%20b.png)\n") { source in asked.append(source); return nil }
        #expect(asked == ["../up/a%20b.png"])
    }
}
