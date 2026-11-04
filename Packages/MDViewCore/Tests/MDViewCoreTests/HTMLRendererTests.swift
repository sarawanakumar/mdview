import Testing
@testable import MDViewCore

@Suite("HTMLEscaping")
struct HTMLEscapingTests {
    @Test func escapesMarkupCharacters() {
        #expect(HTMLEscaping.escape(#"<a href="x">Tom & 'Jerry'</a>"#)
            == "&lt;a href=&quot;x&quot;&gt;Tom &amp; &#39;Jerry&#39;&lt;/a&gt;")
    }

    @Test func leavesOtherTextAlone() {
        #expect(HTMLEscaping.escape("café ✓ 日本") == "café ✓ 日本")
    }
}

@Suite("HTMLRenderer (minimal, roadmap 1.5)")
struct HTMLRendererTests {
    @Test func headingsKeepTheirLevel() {
        let html = HTMLRenderer.render(markdown: "# One\n\n## Two\n\n###### Six\n")
        #expect(html == "<h1>One</h1>\n<h2>Two</h2>\n<h6>Six</h6>\n")
    }

    @Test func setextHeadingsWork() {
        #expect(HTMLRenderer.render(markdown: "Title\n=====\n") == "<h1>Title</h1>\n")
    }

    @Test func paragraphsAndBreaks() {
        let html = HTMLRenderer.render(markdown: "first line\nsame paragraph  \nhard break\n\nsecond\n")
        #expect(html == "<p>first line\nsame paragraph<br>\nhard break</p>\n<p>second</p>\n")
    }

    @Test func inlineFormattingShowsAsText() {
        let html = HTMLRenderer.render(markdown: "Some *em*, **strong** and [a link](https://x.y).\n")
        #expect(html == "<p>Some em, strong and a link.</p>\n")
    }

    @Test func textIsEscaped() {
        #expect(HTMLRenderer.render(markdown: "1 < 2 & 3 > 2\n") == "<p>1 &lt; 2 &amp; 3 &gt; 2</p>\n")
    }

    @Test func inlineHTMLIsShownNotRendered() {
        let html = HTMLRenderer.render(markdown: "Hi <script>alert(1)</script> there\n")
        #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!html.contains("<script"))
    }

    @Test func htmlBlocksAreShownNotRendered() {
        let html = HTMLRenderer.render(markdown: "<div onclick=\"x()\">hi</div>\n")
        #expect(!html.contains("<div"))
        #expect(html.contains("&lt;div onclick=&quot;x()&quot;&gt;hi&lt;/div&gt;"))
    }

    @Test func otherBlocksKeepTheirSourceForNow() {
        let html = HTMLRenderer.render(markdown: "- a\n- b\n")
        #expect(html.hasPrefix("<pre class=\"not-yet-rendered\">"))
        #expect(html.contains("- a") && html.contains("- b"))
    }

    @Test func smartPunctuationIsOff() {
        #expect(HTMLRenderer.render(markdown: "\"x\" -- y...\n") == "<p>&quot;x&quot; -- y...</p>\n")
    }

    @Test func emptyInputGivesEmptyBody() {
        #expect(HTMLRenderer.render(markdown: "") == "")
    }

    @Test func plainTextIsEscapedInPre() {
        #expect(HTMLRenderer.render(plainText: "# not a heading\n<b>")
            == "<pre class=\"plain-text\"># not a heading\n&lt;b&gt;</pre>\n")
    }
}
